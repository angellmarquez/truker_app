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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan));
        }

        final trips = snapshot.data ?? [];
        
        // Filtramos los viajes dependiendo del periodo
        final filteredTrips = _filterTripsByPeriod(trips, _selectedPeriod);
        
        double totalDistance = 0;
        double totalRealFuel = 0;
        double totalEstimatedFuel = 0;

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
            _buildStatGrid(totalDistance, totalRealFuel, totalEstimatedFuel),
            const SizedBox(height: 32),
            const Text(
              'Consumo de Combustible (L)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildFuelChart(filteredTrips),
            ),
          ],
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

  Widget _buildStatGrid(double distance, double realFuel, double estimatedFuel) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Kilómetros', '${distance.toStringAsFixed(1)} km', Icons.route_outlined, AppTheme.primaryCyan),
        _buildStatCard('Consumo Real', '${realFuel.toStringAsFixed(1)} L', Icons.local_gas_station_outlined, Colors.orange),
        _buildStatCard('Estimado', '${estimatedFuel.toStringAsFixed(1)} L', Icons.analytics_outlined, Colors.green),
        // Alertas lo sacaremos de otro stream, así que lo omitimos de este Grid o lo ponemos en 0 temporal
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSlate,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSlate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryCyan,
            barWidth: 4,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryCyan.withOpacity(0.2),
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
