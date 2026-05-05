import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'mensual';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes de Flota')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 24),
            _buildStreamedContent(),
            const SizedBox(height: 32),
            _buildStreamedAlerts(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'mensual', label: Text('Mensual')),
        ButtonSegment(value: 'trimestral', label: Text('Trimestral')),
        ButtonSegment(value: 'anual', label: Text('Anual')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (val) {
        setState(() {
          _selectedPeriod = val.first;
        });
      },
      style: ButtonStyle(
        side: MaterialStateProperty.all(const BorderSide(color: AppTheme.borderSlate)),
        backgroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return AppTheme.primaryCyan.withOpacity(0.2);
          }
          return Colors.transparent;
        }),
      ),
    );
  }

  Widget _buildStreamedContent() {
    return StreamBuilder<List<Trip>>(
      stream: FirebaseService().getTripsStream(),
      builder: (context, tripSnapshot) {
        return StreamBuilder<List<Truck>>(
          stream: FirebaseService().getTrucksStream(),
          builder: (context, truckSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService().getDriversStream(),
              builder: (context, driverSnapshot) {
                if (tripSnapshot.connectionState == ConnectionState.waiting || 
                    truckSnapshot.connectionState == ConnectionState.waiting ||
                    driverSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan));
                }

                final trips = tripSnapshot.data ?? [];
                final trucks = truckSnapshot.data ?? [];
                final drivers = driverSnapshot.data ?? [];
                
                // Mapeos para resolución rápida
                Map<String, String> truckPlates = { for (var t in trucks) t.id : t.licensePlate };
                Map<String, String> driverNames = { for (var d in drivers) d['id'] : d['full_name'] };

                final filteredTrips = _filterTripsByPeriod(trips, _selectedPeriod);
                
                double totalDistance = 0;
                double totalRealFuel = 0;
                double totalEstimatedFuel = 0;
                int totalDeliveries = filteredTrips.length;

                for (var trip in filteredTrips) {
                  totalDistance += trip.distanceKm;
                  totalEstimatedFuel += trip.estimatedConsumption;
                  if (trip.startFuel != null && trip.endFuel != null && trip.startFuel! >= trip.endFuel!) {
                     totalRealFuel += (trip.startFuel! - trip.endFuel!);
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ESTADÍSTICAS GENERALES',
                      style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _buildStatGrid(totalDistance, totalRealFuel, totalDeliveries),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CONSUMO DE FLOTA',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        TextButton(
                          onPressed: () => _showTripDetails(context, filteredTrips, truckPlates, driverNames),
                          child: const Text('DETALLES', style: TextStyle(color: AppTheme.primaryCyan)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.only(top: 20, right: 20, bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSlate.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderSlate),
                      ),
                      child: _buildFuelChart(filteredTrips),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'RENDIMIENTO POR VEHÍCULO',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 16),
                    _buildTruckBreakdown(filteredTrips, truckPlates),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTruckBreakdown(List<Trip> trips, Map<String, String> truckPlates) {
    // Agrupar datos por camión
    Map<String, Map<String, double>> truckData = {};

    for (var trip in trips) {
      final truckId = trip.truckId;
      if (!truckData.containsKey(truckId)) {
        truckData[truckId] = {'km': 0, 'fuel': 0};
      }
      
      truckData[truckId]!['km'] = (truckData[truckId]!['km'] ?? 0) + trip.distanceKm;
      if (trip.startFuel != null && trip.endFuel != null && trip.startFuel! >= trip.endFuel!) {
        truckData[truckId]!['fuel'] = (truckData[truckId]!['fuel'] ?? 0) + (trip.startFuel! - trip.endFuel!);
      }
    }

    if (truckData.isEmpty) {
      return const Center(child: Text('Sin datos por camión', style: TextStyle(color: AppTheme.textMuted)));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: truckData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final truckId = truckData.keys.elementAt(index);
        final plate = truckPlates[truckId] ?? 'Camión Desconocido';
        final stats = truckData[truckId]!;
        final km = stats['km']!;
        final fuel = stats['fuel']!;
        final performance = km > 0 ? (fuel / km * 100).toStringAsFixed(1) : '0.0';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSlate.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSlate.withOpacity(0.5)),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        plate, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$performance L/100km', 
                        style: const TextStyle(color: AppTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                VerticalDivider(color: AppTheme.borderSlate.withOpacity(0.5), indent: 4, endIndent: 4),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${km.toStringAsFixed(0)} KM', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${fuel.toStringAsFixed(0)}L usados', 
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Trip> _filterTripsByPeriod(List<Trip> trips, String period) {
    final now = DateTime.now();
    return trips.where((trip) {
      final diff = now.difference(trip.startTime).inDays;
      if (period == 'mensual') return diff <= 30;
      if (period == 'trimestral') return diff <= 90;
      if (period == 'anual') return diff <= 365;
      return true;
    }).toList();
  }

  Widget _buildStatGrid(double distance, double realFuel, int deliveries) {
    return Column(
      children: [
        // Tarjeta Principal (Hero Stat)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryCyan.withOpacity(0.2), AppTheme.deepNavy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppTheme.primaryCyan.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.speed, color: AppTheme.primaryCyan, size: 40),
              const SizedBox(height: 12),
              Text(
                '${distance.toStringAsFixed(1)} KM',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
              ),
              const Text('RECORRIDO TOTAL DE LA FLOTA', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard('Consumo Real', '${realFuel.toStringAsFixed(1)}L', Icons.local_gas_station, Colors.orange)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Entregas', '$deliveries', Icons.fact_check, Colors.green)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSlate.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSlate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFuelChart(List<Trip> trips) {
    if (trips.isEmpty) {
      return const Center(child: Text('Sin datos suficientes', style: TextStyle(color: AppTheme.textMuted)));
    }

    // Por simplicidad, tomaremos los ultimos 5 viajes para graficar
    trips.sort((a, b) => a.startTime.compareTo(b.startTime));
    final recentTrips = trips.length > 5 ? trips.sublist(trips.length - 5) : trips;

    List<FlSpot> spots = [];
    for (int i = 0; i < recentTrips.length; i++) {
      final trip = recentTrips[i];
      double fuelUsed = 0;
      if (trip.startFuel != null && trip.endFuel != null && trip.startFuel! >= trip.endFuel!) {
        fuelUsed = trip.startFuel! - trip.endFuel!;
      }
      spots.add(FlSpot(i.toDouble(), fuelUsed));
    }

    if (spots.isEmpty || spots.every((spot) => spot.y == 0)) {
       return const Center(child: Text('Sin consumos registrados', style: TextStyle(color: AppTheme.textMuted)));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.borderSlate, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text('V${value.toInt() + 1}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: const LinearGradient(colors: [AppTheme.primaryCyan, Colors.blueAccent]),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppTheme.primaryCyan.withOpacity(0.3), AppTheme.primaryCyan.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamedAlerts() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().getAlertsStream(),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Alertas de Parada Recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${alerts.length} alertas', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (alerts.isEmpty)
               const Text('No hay alertas registradas.', style: TextStyle(color: AppTheme.textMuted)),
            ...alerts.map((alert) {
               final title = alert['truck_id'] != null ? 'Camión ${alert['truck_id']}' : 'Alerta de Camión';
               final desc = alert['reason'] ?? 'Detenido inusualmente';
               
               String timeStr = 'Reciente';
               if (alert['created_at'] != null) {
                 final dt = (alert['created_at'] as Timestamp).toDate();
                 timeStr = DateFormat('dd/MM hh:mm a').format(dt);
               }

               return _buildAlertItem(title, desc, timeStr);
            }).toList(),
          ],
        );
      },
    );
  }

  void _showTripDetails(BuildContext context, List<Trip> trips, Map<String, String> truckPlates, Map<String, String> driverNames) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.deepNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(ctx).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Historial Detallado de Viajes', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(color: AppTheme.borderSlate),
            const SizedBox(height: 16),
            Expanded(
              child: trips.isEmpty 
                ? const Center(child: Text('No hay viajes registrados en este periodo.'))
                : ListView.separated(
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const Divider(color: AppTheme.borderSlate, height: 32),
                    itemBuilder: (ctx, i) {
                      final trip = trips[i];
                      final truckPlate = truckPlates[trip.truckId] ?? 'Desconocido';
                      final driverName = driverNames[trip.driverId] ?? 'Desconocido';
                      final fuelUsed = (trip.startFuel != null && trip.endFuel != null) ? (trip.startFuel! - trip.endFuel!) : 0.0;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(truckPlate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                              ),
                              Text(DateFormat('dd/MM HH:mm').format(trip.startTime), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: AppTheme.primaryCyan),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 3,
                                child: Text(driverName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              ),
                              if (!trip.isActive) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (trip.endTime != null ? Colors.green : Colors.red).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: (trip.endTime != null ? Colors.green : Colors.red).withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    trip.endTime != null ? 'ENTREGADO' : 'LIBERADO',
                                    style: TextStyle(color: (trip.endTime != null ? Colors.green : Colors.red), fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.route_outlined, size: 13, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text('${trip.distanceKm.toStringAsFixed(1)} KM', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Icon(Icons.local_gas_station_outlined, size: 13, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text('${fuelUsed.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (trip.cargoDetails != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSlate.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderSlate.withOpacity(0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 12, color: AppTheme.textMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Carga: ${trip.cargoDetails}', 
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(String title, String desc, String time) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white, size: 16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
      trailing: Text(time, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
    );
  }
}
