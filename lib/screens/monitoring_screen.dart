import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MonitoringScreen extends StatefulWidget {
  static final GlobalKey<_MonitoringScreenState> monitoringKey = GlobalKey<_MonitoringScreenState>();
  MonitoringScreen() : super(key: monitoringKey);

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();

  static void centerOnTruck(String truckId) {
    monitoringKey.currentState?._centerOnTruckById(truckId);
  }
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  Truck? _selectedTruck;
  List<Truck> _allTrucks = [];
  final MapController _mapController = MapController();

  void _centerOnTruckById(String truckId) {
    final truck = _allTrucks.firstWhere((t) => t.id == truckId, orElse: () => Truck(id: '', licensePlate: '', currentFuel: 0, fuelCapacity: 0, status: '', updatedAt: DateTime.now(), consumptionRate: 15));
    if (truck.id.isNotEmpty) {
      _centerOnTruck(truck);
    }
  }

  void _centerOnTruck(Truck truck) {
    if (truck.lastLatitude != null && truck.lastLongitude != null) {
      _mapController.move(LatLng(truck.lastLatitude!, truck.lastLongitude!), 14.0);
      setState(() => _selectedTruck = truck);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo en Vivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              // Solo hacemos signOut(). El StreamBuilder en main.dart
              // detecta el cambio y redirige al Login automáticamente.
              await FirebaseService().signOut();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Truck>>(
            stream: FirebaseService().getTrucksStream(),
            builder: (context, truckSnapshot) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService().getDriversStream(),
                builder: (context, driverSnapshot) {
                  final trucks = truckSnapshot.data ?? [];
                  final drivers = driverSnapshot.data ?? [];
                  _allTrucks = trucks;

                  List<Marker> markers = [];

                  // 1. Marcadores de CAMIONES
                  for (var truck in trucks) {
                    if (truck.lastLatitude == null || truck.lastLongitude == null) continue;

                    final bool isMoving = truck.status == 'moving';
                    final bool isAssigned = truck.assignedDriverId != null;
                    final Color truckColor = isAssigned 
                        ? (isMoving ? AppTheme.primaryCyan : Colors.green) 
                        : Colors.orange;

                    markers.add(
                      Marker(
                        point: LatLng(truck.lastLatitude!, truck.lastLongitude!),
                        width: 85,
                        height: 85,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTruck = truck),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepNavy.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: truckColor, width: 1.5),
                                ),
                                child: Text(
                                  isAssigned 
                                      ? truck.assignedDriverName!.split(' ').first 
                                      : 'Camión Solo',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: truckColor.withOpacity(0.2),
                                      border: Border.all(color: truckColor, width: 2),
                                    ),
                                  ),
                                  Icon(
                                    isAssigned ? Icons.person_pin : Icons.local_shipping,
                                    color: truckColor,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // 2. Marcadores de CONDUCTORES DISPONIBLES (Online pero sin camión)
                  for (var driver in drivers) {
                    final bool isOnline = driver['is_online'] == true;
                    final bool isAssigned = driver['assigned_truck_id'] != null;
                    final double? lat = driver['last_latitude'];
                    final double? lng = driver['last_longitude'];

                    if (isOnline && !isAssigned && lat != null && lng != null) {
                      markers.add(
                        Marker(
                          point: LatLng(lat, lng),
                          width: 80,
                          height: 80,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primaryCyan),
                                ),
                                child: Text(
                                  driver['full_name']?.split(' ').first ?? 'Driver',
                                  style: const TextStyle(color: AppTheme.primaryCyan, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Icon(Icons.person_pin_circle, color: AppTheme.primaryCyan, size: 34),
                            ],
                          ),
                        ),
                      );
                    }
                  }

                  return FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      initialCenter: LatLng(10.4806, -66.8983),
                      initialZoom: 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.truckfleet.app',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  );
                },
              );
            },
          ),
          if (_selectedTruck != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                color: AppTheme.deepNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: AppTheme.primaryCyan, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Camión: ${_selectedTruck!.licensePlate}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.my_location, color: AppTheme.primaryCyan),
                              tooltip: 'Localizar en mapa',
                              onPressed: () => _centerOnTruck(_selectedTruck!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => setState(() => _selectedTruck = null),
                          ),
                        ],
                      ),
                      const Divider(color: AppTheme.borderSlate),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _selectedTruck!.status == 'moving' ? Icons.moving : Icons.pause_circle_filled,
                            color: _selectedTruck!.status == 'moving' ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTruck!.status == 'moving' ? "En movimiento" : "Detenido",
                            style: TextStyle(color: _selectedTruck!.status == 'moving' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person, color: AppTheme.primaryCyan, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Conductor: ${_selectedTruck!.assignedDriverName ?? 'Sin asignar'}",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, color: AppTheme.primaryCyan, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Carga: ${_selectedTruck!.currentCargo ?? 'N/A'}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.primaryCyan, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Destino: ${_selectedTruck!.destination ?? 'N/A'}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Coordenadas: ${_selectedTruck!.lastLatitude?.toStringAsFixed(4) ?? '0'}, ${_selectedTruck!.lastLongitude?.toStringAsFixed(4) ?? '0'}",
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.primaryCyan,
          icon: const Icon(Icons.format_list_bulleted, color: Colors.black, size: 24),
          label: const Text(
            'VER FLOTA',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          onPressed: () => _showTruckList(context),
        ),
      ),
    );
  }

  void _showTruckList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.deepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nuestra Flota',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allTrucks.length,
                  itemBuilder: (context, index) {
                    final truck = _allTrucks[index];
                    final hasLocation = truck.lastLatitude != null;
                    return ListTile(
                      leading: Icon(
                        Icons.local_shipping,
                        color: truck.status == 'moving' ? Colors.green : AppTheme.primaryCyan,
                      ),
                      title: Text(truck.licensePlate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(truck.assignedDriverName ?? 'Sin conductor',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('Actualizado: ${_getTimeAgo(truck.updatedAt)}',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (truck.status == 'moving' ? Colors.green : Colors.orange).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              truck.status == 'moving' ? 'MOVIMIENTO' : 'DETENIDO',
                              style: TextStyle(
                                color: truck.status == 'moving' ? Colors.green : Colors.orange,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${truck.currentFuel.toStringAsFixed(0)}L', 
                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (hasLocation) {
                          _centerOnTruck(truck);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Este camión no tiene ubicación registrada.')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return 'Hace ${diff.inDays}d';
  }
}
