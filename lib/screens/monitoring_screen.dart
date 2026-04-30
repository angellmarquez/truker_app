import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  Truck? _selectedTruck;
  final MapController _mapController = MapController();

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
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan));
              }

              final trucks = snapshot.data ?? [];
              final markers = trucks.where((t) => t.lastLatitude != null && t.lastLongitude != null).map((truck) {
                final isMoving = truck.status == 'moving';
                final isAssigned = truck.assignedDriverId != null;
                
                Color truckColor;
                if (isMoving) {
                  truckColor = Colors.green;
                } else if (isAssigned) {
                  truckColor = Colors.orange;
                } else {
                  truckColor = AppTheme.primaryCyan; // Azul claro
                }

                return Marker(
                  point: LatLng(truck.lastLatitude!, truck.lastLongitude!),
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTruck = truck),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMoving ? AppTheme.deepNavy : Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: truckColor, width: 2),
                            boxShadow: isMoving ? [BoxShadow(color: truckColor.withOpacity(0.5), blurRadius: 4)] : null,
                          ),
                          child: Text(
                            truck.licensePlate,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: truckColor.withOpacity(0.2),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.local_shipping,
                            color: truckColor,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList();

              return FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(10.4806, -66.8983), // Caracas por defecto
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
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
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
    );
  }
}
