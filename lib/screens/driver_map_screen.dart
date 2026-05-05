import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentPosition;
  bool _isTripActive = false;
  double _distanceTravelled = 0.0;
  double _currentSpeed = 0.0;
  Map<String, dynamic>? _assignment; // Datos de asignación del Admin

  StreamSubscription? _assignmentSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseService().updatePresence(true);
    _requestPermissionsAndStartLocation();
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _assignmentSubscription = FirebaseService.firestore
        .collection('profiles')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() => _assignment = doc.data());
      }
    });
  }

  Future<void> _requestPermissionsAndStartLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Get initial position
    final initPos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _currentPosition = LatLng(initPos.latitude, initPos.longitude);
      _mapController.move(_currentPosition!, 16.0);
    });

    // Start listening
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          final newPos = LatLng(position.latitude, position.longitude);
          if (_isTripActive && _currentPosition != null) {
            _distanceTravelled += Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude,
              newPos.latitude, newPos.longitude,
            );
          }
          _currentPosition = newPos;
          _currentSpeed = (position.speed * 3.6); // Convert m/s to km/h
          
          _mapController.move(_currentPosition!, _mapController.camera.zoom);
        });

        // Siempre actualizar Firebase si hay un camión asignado
        _updateFirebaseLocation(position.latitude, position.longitude);
      }
    });
  }

  Future<void> _updateFirebaseLocation(double lat, double lng) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // 1. Siempre actualizar la ubicación del conductor (perfil)
      await FirebaseService().updateDriverLocation(uid, lat, lng);

      // 2. Si tiene un camión asignado, actualizar la ubicación del camión
      final truckId = _assignment?['assigned_truck_id'];
      if (truckId != null) {
        await FirebaseService().updateLocation(
          truckId, 
          lat, 
          lng, 
          _isTripActive 
        );
      }
    }
  }

  void _toggleTrip() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final newState = !_isTripActive;
    
    // Si estamos iniciando el viaje
    if (newState) {
      final profile = await FirebaseService().getUserProfile(uid);
      if (profile?.assignedTruckId != null) {
        // Obtener el camión para saber el combustible inicial
        final truckDoc = await FirebaseService.firestore.collection('trucks').doc(profile!.assignedTruckId).get();
        final truckData = truckDoc.data();
        if (truckData != null) {
          await FirebaseService().startTrip(
            profile.assignedTruckId!,
            truckData['current_cargo'] ?? 'Carga General',
            (truckData['current_fuel'] ?? 0.0).toDouble(),
            (truckData['consumption_rate_l100km'] ?? 15.0).toDouble(),
          );
        }
      }
    }

    setState(() {
      _isTripActive = newState;
      if (!_isTripActive) {
        // Reset distance when stopping (o podrías guardarla antes de resetear)
        _distanceTravelled = 0.0;
        _currentSpeed = 0.0;
      }
    });
    
    // Actualizar estado de asignación del conductor en la base de datos
    await FirebaseService().updateTripStatus(uid, _isTripActive);

    // Si acaba de detenerse, actualizamos firebase para marcar "detenido" en el camión
    if (!_isTripActive && _currentPosition != null) {
      final profile = await FirebaseService().getUserProfile(uid);
      if (profile?.assignedTruckId != null) {
        await FirebaseService().updateLocation(
          profile!.assignedTruckId!, 
          _currentPosition!.latitude, 
          _currentPosition!.longitude, 
          false
        );
      }
    }
  }

  Future<void> _deliverCargo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final profile = await FirebaseService().getUserProfile(uid);
    final truckId = profile?.assignedTruckId;
    if (truckId == null) return;

    // Pedir el combustible final antes de reportar
    final fuelController = TextEditingController();
    final fuel = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.deepNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.primaryCyan)),
        title: const Text('Confirmar Entrega', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa el combustible actual del camión (L):', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: fuelController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surfaceSlate,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixText: 'L',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(fuelController.text);
              if (val != null) Navigator.pop(ctx, val);
            },
            child: const Text('Reportar'),
          ),
        ],
      ),
    );

    if (fuel == null) return;

    // Mostrar indicador de carga
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
    );

    try {
      await FirebaseService().markDeliveryCompleted(
        driverId: uid,
        truckId: truckId,
        distance: _distanceTravelled / 1000, // Convertir metros a KM
        endFuel: fuel,
      );

      setState(() {
        _isTripActive = false;
        _distanceTravelled = 0.0;
        _currentSpeed = 0.0;
      });

      if (mounted) {
        Navigator.pop(context); // Cerrar indicador
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carga entregada exitosamente. Esperando nueva asignación.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar indicador
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la entrega: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FirebaseService().updatePresence(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      FirebaseService().updatePresence(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FirebaseService().updatePresence(false);
    _positionStream?.cancel();
    _assignmentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Viaje'),
        actions: [
           IconButton(
             icon: const Icon(Icons.logout),
             onPressed: () async {
               // Solo signOut(). main.dart redirige solo al login.
               await FirebaseService().signOut();
             },
           )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(10.4806, -66.8983),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.truckfleet.app',
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_isTripActive ? AppTheme.primaryCyan : Colors.orange).withOpacity(0.3),
                            ),
                          ),
                          Icon(
                            Icons.navigation,
                            color: _isTripActive ? AppTheme.primaryCyan : Colors.orange,
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Dashboard Inferior
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: const BoxDecoration(
                color: AppTheme.deepNavy,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de arrastre
                  Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),

                  // Tarjeta de asignación del Admin
                  if (_assignment != null && _assignment!['assignment_status'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSlate,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.4)),
                      ),
                      child: Column(children: [
                        Row(children: [
                          const Icon(Icons.assignment_turned_in, color: AppTheme.primaryCyan, size: 16),
                          const SizedBox(width: 6),
                          const Text('MISIÓN ASIGNADA', style: TextStyle(color: AppTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Activa', style: TextStyle(color: Colors.green, fontSize: 10)),
                          ),
                        ]),
                        const Divider(color: AppTheme.borderSlate, height: 16),
                        _assignmentRow(Icons.local_shipping_outlined, 'Camión', _assignment!['assigned_truck_plate'] ?? 'N/A'),
                        const SizedBox(height: 6),
                        _assignmentRow(Icons.inventory_2_outlined, 'Carga', _assignment!['current_cargo'] ?? 'N/A'),
                        const SizedBox(height: 6),
                        _assignmentRow(Icons.location_on_outlined, 'Destino', _assignment!['destination'] ?? 'N/A'),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    // Sin asignación
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSlate,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderSlate),
                      ),
                      child: const Row(children: [
                        Icon(Icons.hourglass_empty, color: AppTheme.textMuted, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text('Esperando asignación del Admin...', style: TextStyle(color: AppTheme.textMuted))),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Métricas de velocidad y distancia
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricPanel('Velocidad', '${_currentSpeed.toStringAsFixed(0)} km/h', Icons.speed),
                      _buildMetricPanel('Distancia', '${(_distanceTravelled / 1000).toStringAsFixed(1)} km', Icons.route),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Botón Iniciar/Detener Viaje
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      // Solo activar si tiene asignación y no ha reportado entrega
                      onPressed: (_assignment != null && _assignment!['assignment_status'] != null && _assignment!['assignment_status'] != 'delivered') 
                          ? _toggleTrip 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTripActive ? Colors.red.shade600 : AppTheme.primaryCyan,
                        disabledBackgroundColor: Colors.grey.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text(
                        _isTripActive ? 'DETENER VIAJE' : 
                        (_assignment?['assignment_status'] == 'delivered' ? 'ENTREGA REPORTADA' :
                        (_assignment?['assignment_status'] != null ? 'INICIAR VIAJE' : 'SIN ASIGNACIÓN')),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isTripActive ? Colors.white : 
                                 (_assignment?['assignment_status'] != null ? Colors.black : Colors.grey),
                        ),
                      ),
                    ),
                  ),

                  // Botón Entregar Carga o Mensaje de Espera
                  if (_assignment != null && _assignment!['assignment_status'] != null) ...[
                    if (_assignment!['assignment_status'] != 'delivered') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          onPressed: _deliverCargo,
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          label: const Text(
                            'ENTREGAR CARGA',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.green, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_bottom, color: Colors.green, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Entrega reportada. Esperando que el administrador lo libere...',
                                style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _assignmentRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 14, color: AppTheme.textMuted),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildMetricPanel(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(title, style: const TextStyle(color: AppTheme.textMuted)),
      ],
    );
  }
}
