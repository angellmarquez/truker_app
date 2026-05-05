import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../models/models.dart';

class FirebaseService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // --- AUTHENTICATION ---
  
  Future<UserCredential> signIn(String email, String password) async {
    return await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  // --- PROFILE ---

  Future<UserProfile?> getUserProfile(String userId) async {
    final doc = await firestore.collection('profiles').doc(userId).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  /// Crea un conductor usando la REST API de Firebase Auth.
  /// NO afecta la sesión actual del Admin (no usa auth.createUser que inicia sesión).
  /// Si la cuenta ya existe en Auth, reutiliza el UID existente.
  Future<Map<String, String>> createDriver({
    required String fullName,
    required String licenseNumber,
    String? assignedTruckId,
    String? currentCargo,
  }) async {
    final email = '${licenseNumber.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@flota.app';
    final password = 'Flota${licenseNumber.toUpperCase()}2024!';

    // Obtener el API Key de Firebase desde la config de la app
    final apiKey = Firebase.app().options.apiKey;
    String newDriverUid;

    // Primero intentar crear el usuario via REST API
    print('DEBUG: Intentando signUp para $email');
    final signUpResponse = await http.post(
      Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}),
    );

    final signUpBody = jsonDecode(signUpResponse.body);
    print('DEBUG: signUp status: ${signUpResponse.statusCode}');
    if (signUpResponse.statusCode != 200) {
      print('DEBUG: signUp error body: ${signUpResponse.body}');
    }

    if (signUpResponse.statusCode == 200) {
      newDriverUid = signUpBody['localId'];
    } else if (signUpBody['error']?['message'] == 'EMAIL_EXISTS') {
      print('DEBUG: El email ya existe. Intentando signIn para obtener UID...');
      final signInResponse = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}),
      );
      final signInBody = jsonDecode(signInResponse.body);
      if (signInResponse.statusCode != 200) {
        print('DEBUG: signIn error body: ${signInResponse.body}');
        throw Exception('Error al recuperar conductor existente: ${signInBody['error']?['message']}');
      }
      newDriverUid = signInBody['localId'];
    } else {
      throw Exception('Error creando usuario: ${signUpBody['error']?['message']}');
    }

    // Guardar/actualizar el perfil en Firestore
    await firestore.collection('profiles').doc(newDriverUid).set({
      'full_name': fullName,
      'license_number': licenseNumber,
      'role': 'driver',
      'is_active': false,
      'assigned_truck_id': assignedTruckId,
      'current_cargo': currentCargo,
      'created_at': FieldValue.serverTimestamp(),
    });

    if (assignedTruckId != null) {
      await firestore.collection('trucks').doc(assignedTruckId).update({
        'assigned_driver_id': newDriverUid,
        'assigned_driver_name': fullName,
      });
    }

    return {'email': email, 'password': password};
  }

  // Actualizar estado online/offline del conductor
  Future<void> updatePresence(bool isOnline) async {
    final user = auth.currentUser;
    if (user != null) {
      try {
        await firestore.collection('profiles').doc(user.uid).update({
          'is_online': isOnline,
          'last_seen': FieldValue.serverTimestamp(),
        });
        print('DEBUG: Presencia actualizada a $isOnline para ${user.email}');
      } catch (e) {
        print('DEBUG: Error actualizando presencia: $e');
      }
    }
  }

  Future<void> createTruck({
    required String licensePlate,
    String? engineSerial,
    required double fuelCapacity,
    double consumptionRate = 15.0,
  }) async {
    await firestore.collection('trucks').add({
      'license_plate': licensePlate,
      'engine_serial': engineSerial,
      'fuel_capacity': fuelCapacity,
      'current_fuel': fuelCapacity,
      'consumption_rate_l100km': consumptionRate,
      'status': 'stopped',
      'last_latitude': null,
      'last_longitude': null,
      'assigned_driver_id': null,
      'assigned_driver_name': null,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getDriversStream() {
    return firestore
        .collection('profiles')
        .where('role', isEqualTo: 'driver')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// El Admin asigna camión, mercancía y destino a un conductor disponible.
  Future<void> assignTripToDriver({
    required String driverId,
    required String truckId,
    required String truckPlate,
    required String cargo,
    required String destination,
    required String driverName,
  }) async {
    await firestore.collection('profiles').doc(driverId).update({
      'assigned_truck_id': truckId,
      'assigned_truck_plate': truckPlate,
      'current_cargo': cargo,
      'destination': destination,
      'assignment_status': 'assigned',
      'assigned_at': FieldValue.serverTimestamp(),
      'is_active': true, // Marcar como activo al asignar
    });

    // También actualizar el camión con el driver asignado, carga y destino
    await firestore.collection('trucks').doc(truckId).update({
      'assigned_driver_id': driverId,
      'assigned_driver_name': driverName,
      'current_cargo': cargo,
      'destination': destination,
    });
  }

  /// El Admin libera a un conductor (cuando completó el viaje o por intervención manual)
  Future<void> clearDriverAssignment(String driverId, String? truckId) async {
    // 1. Limpiar perfiles
    await firestore.collection('profiles').doc(driverId).update({
      'assigned_truck_id': null,
      'assigned_truck_plate': null,
      'current_cargo': null,
      'destination': null,
      'assignment_status': null,
      'is_active': false,
      'delivery_photo_url': null,
      'delivery_completed_at': null,
    });

    // 2. Limpiar camión
    if (truckId != null) {
      await firestore.collection('trucks').doc(truckId).update({
        'assigned_driver_id': null,
        'assigned_driver_name': null,
        'current_cargo': null,
        'destination': null,
        'status': 'stopped',
      });
    }

    // 3. Cerrar cualquier viaje activo para este conductor (Intervención Admin)
    final activeTrips = await firestore.collection('trips')
        .where('driver_id', isEqualTo: driverId)
        .where('is_active', isEqualTo: true)
        .get();
    
    for (var doc in activeTrips.docs) {
      await firestore.collection('trips').doc(doc.id).update({
        'is_active': false,
        // No ponemos end_time si fue una liberación manual sin entrega, 
        // así distinguimos en el reporte.
      });
    }
  }

  /// El conductor inicia o detiene el viaje (para rastreo en tiempo real)
  Future<void> updateTripStatus(String driverId, bool isActive) async {
    await firestore.collection('profiles').doc(driverId).update({
      'is_active': isActive,
      'assignment_status': isActive ? 'in_progress' : 'assigned',
    });
  }

  /// Marca el viaje como completado (carga entregada)
  Future<void> markDeliveryCompleted({
    required String driverId,
    required String truckId,
    required double distance,
    required double endFuel,
  }) async {
    // Actualizar el perfil del conductor indicando entrega completada
    await firestore.collection('profiles').doc(driverId).update({
      'is_active': false,
      'assignment_status': 'delivered',
      'delivery_completed_at': FieldValue.serverTimestamp(),
    });

    // Guardar en el historial de viajes del camión
    final tripsQuery = await firestore.collection('trips')
        .where('driver_id', isEqualTo: driverId)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    if (tripsQuery.docs.isNotEmpty) {
      await firestore.collection('trips').doc(tripsQuery.docs.first.id).update({
        'is_active': false,
        'end_time': FieldValue.serverTimestamp(),
        'end_fuel': endFuel,
        'distance_km': distance,
      });
    }

    // Actualizar el camión: detenerlo y actualizar su combustible actual
    await firestore.collection('trucks').doc(truckId).update({
      'status': 'stopped',
      'current_fuel': endFuel,
    });
  }

  /// El admin rechaza la entrega y devuelve al conductor a estado "En Ruta"
  Future<void> rejectDelivery(String driverId) async {
    await firestore.collection('profiles').doc(driverId).update({
      'assignment_status': 'in_progress',
      'delivery_completed_at': null,
    });
    
    // Buscar el último viaje finalizado de este conductor para reactivarlo
    final tripsQuery = await firestore.collection('trips')
        .where('driver_id', isEqualTo: driverId)
        .where('is_active', isEqualTo: false)
        .orderBy('end_time', descending: true)
        .limit(1)
        .get();

    if (tripsQuery.docs.isNotEmpty) {
      await firestore.collection('trips').doc(tripsQuery.docs.first.id).update({
        'is_active': true,
        'end_time': null,
      });
    }
  }

  /// Elimina un conductor de Firestore (no borra de Auth, solo el perfil)
  Future<void> deleteDriverProfile(String driverId) async {
    await firestore.collection('profiles').doc(driverId).delete();
  }

  Future<void> deleteTruck(String truckId) async {
    // Antes de borrar, limpiamos la asignación del conductor si existe
    final doc = await firestore.collection('trucks').doc(truckId).get();
    if (doc.exists) {
      final data = doc.data();
      final driverId = data?['assigned_driver_id'];
      if (driverId != null) {
        await firestore.collection('profiles').doc(driverId).update({
          'assigned_truck_id': null,
          'assigned_truck_plate': null,
          'current_cargo': null,
          'destination': null,
          'assignment_status': null,
          'is_active': false,
        });
      }
    }
    await firestore.collection('trucks').doc(truckId).delete();
  }

  // --- TRUCKS & TRACKING ---

  Stream<List<Truck>> getTrucksStream() {
    return firestore.collection('trucks').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Truck.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> updateLocation(String truckId, double lat, double lon, bool isMoving) async {
    await firestore.collection('trucks').doc(truckId).update({
      'last_latitude': lat,
      'last_longitude': lon,
      'status': isMoving ? 'moving' : 'stopped',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDriverLocation(String driverId, double lat, double lon) async {
    await firestore.collection('profiles').doc(driverId).update({
      'last_latitude': lat,
      'last_longitude': lon,
      'last_seen': FieldValue.serverTimestamp(),
    });
  }

  // --- TRIPS & FUEL ---

  Future<void> startTrip(String truckId, String cargo, double startFuel, double consumptionRate) async {
    if (auth.currentUser == null) return;
    
    await firestore.collection('trips').add({
      'truck_id': truckId,
      'driver_id': auth.currentUser!.uid,
      'cargo_details': cargo,
      'start_fuel': startFuel,
      'consumption_rate': consumptionRate,
      'start_time': FieldValue.serverTimestamp(),
      'is_active': true,
      'distance_km': 0.0,
    });
  }

  Stream<List<Trip>> getTripsStream() {
    return firestore.collection('trips').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Trip.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> endTrip(String tripId, double endFuel, double distance) async {
    await firestore.collection('trips').doc(tripId).update({
      'end_time': FieldValue.serverTimestamp(),
      'end_fuel': endFuel,
      'distance_km': distance,
      'is_active': false,
    });
  }

  // --- ALERTS ---

  Stream<List<Map<String, dynamic>>> getAlertsStream() {
    return firestore
        .collection('alerts')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }
}
