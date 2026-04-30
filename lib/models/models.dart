import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, driver }

class Truck {
  final String id;
  final String licensePlate;
  final String? engineSerial;
  final double fuelCapacity;
  final double currentFuel;
  final double consumptionRate;
  final double? lastLatitude;
  final double? lastLongitude;
  final String status;
  final DateTime updatedAt;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? currentCargo;
  final String? destination;

  Truck({
    required this.id,
    required this.licensePlate,
    this.engineSerial,
    required this.fuelCapacity,
    required this.currentFuel,
    required this.consumptionRate,
    this.lastLatitude,
    this.lastLongitude,
    required this.status,
    required this.updatedAt,
    this.assignedDriverId,
    this.assignedDriverName,
    this.currentCargo,
    this.destination,
  });

  factory Truck.fromJson(Map<String, dynamic> json, String documentId) {
    return Truck(
      id: documentId,
      licensePlate: json['license_plate'] ?? '',
      engineSerial: json['engine_serial'],
      fuelCapacity: (json['fuel_capacity'] ?? 0.0).toDouble(),
      currentFuel: (json['current_fuel'] ?? 0.0).toDouble(),
      consumptionRate: (json['consumption_rate_l100km'] ?? 15.0).toDouble(),
      lastLatitude: json['last_latitude']?.toDouble(),
      lastLongitude: json['last_longitude']?.toDouble(),
      status: json['status'] ?? 'stopped',
      assignedDriverId: json['assigned_driver_id'],
      assignedDriverName: json['assigned_driver_name'],
      currentCargo: json['current_cargo'],
      destination: json['destination'],
      updatedAt: json['updated_at'] != null 
          ? (json['updated_at'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}

class UserProfile {
  final String id;
  final String fullName;
  final String? licenseNumber;
  final UserRole role;
  final String? qrToken;
  final String? assignedTruckId;

  UserProfile({
    required this.id,
    required this.fullName,
    this.licenseNumber,
    required this.role,
    this.qrToken,
    this.assignedTruckId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, String documentId) {
    return UserProfile(
      id: documentId,
      fullName: json['full_name'] ?? 'Usuario',
      licenseNumber: json['license_number'],
      role: json['role'] == 'admin' ? UserRole.admin : UserRole.driver,
      qrToken: json['qr_token'],
      assignedTruckId: json['assigned_truck_id'],
    );
  }
}

class Trip {
  final String id;
  final String truckId;
  final String driverId;
  final String? cargoDetails;
  final DateTime startTime;
  final DateTime? endTime;
  final double? startFuel;
  final double? endFuel;
  final double distanceKm;
  final bool isActive;

  Trip({
    required this.id,
    required this.truckId,
    required this.driverId,
    this.cargoDetails,
    required this.startTime,
    this.endTime,
    this.startFuel,
    this.endFuel,
    required this.distanceKm,
    required this.isActive,
  });

  // Lógica de consumo estimado
  double get estimatedConsumption {
    return (distanceKm / 100) * 15.0;
  }

  factory Trip.fromJson(Map<String, dynamic> json, String documentId) {
    return Trip(
      id: documentId,
      truckId: json['truck_id'] ?? '',
      driverId: json['driver_id'] ?? '',
      cargoDetails: json['cargo_details'],
      startTime: json['start_time'] != null 
          ? (json['start_time'] as Timestamp).toDate() 
          : DateTime.now(),
      endTime: json['end_time'] != null 
          ? (json['end_time'] as Timestamp).toDate() 
          : null,
      startFuel: json['start_fuel']?.toDouble(),
      endFuel: json['end_fuel']?.toDouble(),
      distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
      isActive: json['is_active'] ?? false,
    );
  }
}
