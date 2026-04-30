import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

class AdminUtils {
  static void showQRDialog(BuildContext context, String name, String email, String password) {
    final qrData = '{"email":"$email","password":"$password"}';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.deepNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.primaryCyan)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: AppTheme.primaryCyan),
          const SizedBox(width: 8),
          Expanded(child: Text('¡$name!', style: const TextStyle(color: Colors.white, fontSize: 16))),
        ]),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Escanea este código con la tablet del conductor para iniciar sesión.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: QrImageView(data: qrData, version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.surfaceSlate, borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  _credRow('Correo:', email),
                  const SizedBox(height: 4),
                  _credRow('Clave:', password),
                ]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CERRAR', style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _credRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryCyan,
          labelColor: AppTheme.primaryCyan,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt), text: 'Conductores'),
            Tab(icon: Icon(Icons.person_add_alt_1), text: 'Registrar'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Camiones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DriversListTab(),
          _RegisterDriverTab(),
          _RegisterTruckTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 1: Lista de conductores con asignación desde aquí
// ─────────────────────────────────────────────────────────────
class _DriversListTab extends StatelessWidget {
  const _DriversListTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().getDriversStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan));
        }

        final drivers = snapshot.data ?? [];
        if (drivers.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.people_outline, size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text('No hay conductores registrados.', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt_1, color: AppTheme.primaryCyan),
                label: const Text('Ve a "Registrar" para añadir uno', style: TextStyle(color: AppTheme.primaryCyan)),
              ),
            ]),
          );
        }

        final assigned = drivers.where((d) => d['assignment_status'] != null).toList();
        final available = drivers.where((d) => d['assignment_status'] == null).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (assigned.isNotEmpty) ...[
              _sectionHeader('En servicio', assigned.length, Colors.green),
              const SizedBox(height: 8),
              ...assigned.map((d) => _DriverCard(data: d, context: context)),
              const SizedBox(height: 20),
            ],
            _sectionHeader('Disponibles', available.length, AppTheme.primaryCyan),
            const SizedBox(height: 8),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todos los conductores están en servicio.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            ...available.map((d) => _DriverCard(data: d, context: context)),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ]);
  }
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final BuildContext context;
  const _DriverCard({required this.data, required this.context});

  bool get isAssigned => data['assignment_status'] != null;

  void _showAssignDialog(BuildContext ctx) {
    final cargoController = TextEditingController(text: data['current_cargo'] ?? '');
    final destController = TextEditingController(text: data['destination'] ?? '');
    String? selectedTruckId = data['assigned_truck_id'];
    String? selectedTruckPlate = data['assigned_truck_plate'];

    showDialog(
      context: ctx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.deepNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.primaryCyan),
          ),
          title: Text('Asignar viaje a ${data['full_name']}',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Selector de camión
              StreamBuilder<List<Truck>>(
                stream: FirebaseService().getTrucksStream(),
                builder: (ctx, snapshot) {
                  final trucks = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: selectedTruckId,
                    dropdownColor: AppTheme.deepNavy,
                    decoration: InputDecoration(
                      labelText: 'Camión *',
                      prefixIcon: const Icon(Icons.local_shipping_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.borderSlate),
                      ),
                    ),
                    hint: const Text('Selecciona un camión', style: TextStyle(color: AppTheme.textMuted)),
                    items: trucks.map((t) => DropdownMenuItem<String>(
                      value: t.id,
                      child: Text(t.licensePlate, style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedTruckId = val;
                        final found = trucks.where((t) => t.id == val).toList();
                        selectedTruckPlate = found.isNotEmpty ? found.first.licensePlate : val;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cargoController,
                decoration: InputDecoration(
                  labelText: 'Mercancía a transportar *',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  hintText: 'Ej: Cemento 500 sacos',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderSlate),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: destController,
                decoration: InputDecoration(
                  labelText: 'Destino *',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  hintText: 'Ej: Av. Principal, Caracas',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderSlate),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedTruckId == null || cargoController.text.trim().isEmpty || destController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Completa todos los campos.'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await FirebaseService().assignTripToDriver(
                  driverId: data['id'],
                  truckId: selectedTruckId!,
                  truckPlate: selectedTruckPlate!,
                  cargo: cargoController.text.trim(),
                  destination: destController.text.trim(),
                  driverName: data['full_name'] ?? 'Conductor',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Viaje asignado a ${data['full_name']} ✓'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text('ASIGNAR VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.deepNavy,
        title: const Text('Liberar conductor', style: TextStyle(color: Colors.white)),
        content: Text('¿Confirmas que ${data['full_name']} completó su viaje y está disponible?',
            style: const TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseService().clearDriverAssignment(data['id'], data['assigned_truck_id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('LIBERAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSlate,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isAssigned ? Colors.green.withOpacity(0.3) : AppTheme.borderSlate),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: (isAssigned ? Colors.green : AppTheme.primaryCyan).withOpacity(0.15),
            child: Text(
              (data['full_name'] ?? 'U')[0].toUpperCase(),
              style: TextStyle(
                color: isAssigned ? Colors.green : AppTheme.primaryCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: (data['is_online'] == true) ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: (data['is_online'] == true) ? [
                    BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 4)
                  ] : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(data['full_name'] ?? 'Sin nombre',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            Text('Licencia: ${data['license_number'] ?? 'N/A'} • ${(data['is_online'] == true) ? "En línea" : "Desconectado"}',
                style: TextStyle(color: (data['is_online'] == true) ? Colors.green : AppTheme.textMuted, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: !(data['is_online'] == true) 
                  ? Colors.grey.withOpacity(0.12)
                  : (data['assignment_status'] == 'delivered' ? Colors.green.shade800 : (data['assignment_status'] == 'in_progress' ? Colors.green : (isAssigned ? Colors.orange : AppTheme.primaryCyan))).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              !(data['is_online'] == true) 
                  ? 'FUERA DE SERVICIO' 
                  : (data['assignment_status'] == 'delivered' ? 'ENTREGADO' : (data['assignment_status'] == 'in_progress' ? 'EN RUTA' : (isAssigned ? 'ASIGNADO' : 'DISPONIBLE'))),
              style: TextStyle(
                color: !(data['is_online'] == true)
                    ? Colors.grey
                    : (data['assignment_status'] == 'delivered' ? Colors.green.shade400 : (data['assignment_status'] == 'in_progress' ? Colors.green : (isAssigned ? Colors.orange : AppTheme.primaryCyan))),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]),
        // Mostrar detalles si está asignado
        if (isAssigned) ...[
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderSlate),
          const SizedBox(height: 8),
          _infoRow(Icons.local_shipping_outlined, 'Camión', data['assigned_truck_plate'] ?? 'N/A'),
          _infoRow(Icons.inventory_2_outlined, 'Carga', data['current_cargo'] ?? 'N/A'),
          _infoRow(Icons.location_on_outlined, 'Destino', data['destination'] ?? 'N/A'),
        ],
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (isAssigned && data['assignment_status'] == 'delivered') ...[
            // Botón de Rechazar
            OutlinedButton.icon(
              onPressed: () async {
                await FirebaseService().rejectDelivery(data['id']);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entrega rechazada. El conductor vuelve a estado en ruta.'), backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Rechazar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
            const SizedBox(width: 8),
            // Botón de Aceptar (que es el mismo Liberar)
            ElevatedButton.icon(
              onPressed: () => _showClearDialog(context),
              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.black),
              label: const Text('Aceptar y Liberar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ] else if (isAssigned) ...[
            // Botón normal de liberar (si aún no ha reportado entrega)
            OutlinedButton.icon(
              onPressed: () => _showClearDialog(context),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Liberar Conductor'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
          if (!isAssigned)
            ElevatedButton.icon(
              onPressed: (data['is_online'] == true) ? () => _showAssignDialog(context) : null,
              icon: Icon(Icons.assignment_outlined, size: 16, color: (data['is_online'] == true) ? Colors.black : Colors.grey),
              label: Text('Asignar Viaje', style: TextStyle(color: (data['is_online'] == true) ? Colors.black : Colors.grey, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: (data['is_online'] == true) ? AppTheme.primaryCyan : AppTheme.surfaceSlate,
                disabledBackgroundColor: AppTheme.surfaceSlate.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          const SizedBox(width: 8),
          // Botón ver QR
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: AppTheme.primaryCyan, size: 24),
            tooltip: 'Ver código QR de acceso',
            onPressed: () {
              final email = '${data['license_number'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@flota.app';
              final password = 'Flota${data['license_number'].toString().toUpperCase()}2024!';
              AdminUtils.showQRDialog(context, data['full_name'], email, password);
            },
          ),
          const SizedBox(width: 4),
          // Botón eliminar conductor
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            tooltip: 'Eliminar conductor',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.deepNavy,
                title: const Text('Eliminar conductor', style: TextStyle(color: Colors.white)),
                content: Text('¿Eliminar a ${data['full_name']}? Esta acción no se puede deshacer.',
                    style: const TextStyle(color: AppTheme.textMuted)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx),
                      child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted))),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await FirebaseService().deleteDriverProfile(data['id']);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('ELIMINAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 2: Registrar Conductor (solo nombre, apellido, licencia)
// ─────────────────────────────────────────────────────────────
class _RegisterDriverTab extends StatefulWidget {
  const _RegisterDriverTab();

  @override
  State<_RegisterDriverTab> createState() => _RegisterDriverTabState();
}

class _RegisterDriverTabState extends State<_RegisterDriverTab> {
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _registerDriver() async {
    final name = _nameController.text.trim();
    final license = _licenseController.text.trim();

    if (name.isEmpty || license.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y licencia son obligatorios.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credentials = await FirebaseService().createDriver(
        fullName: name,
        licenseNumber: license,
      );

      if (!mounted) return;
      _nameController.clear();
      _licenseController.clear();
      AdminUtils.showQRDialog(context, name, credentials['email']!, credentials['password']!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar conductor: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _credRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Registrar Nuevo Conductor',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan)),
        const SizedBox(height: 6),
        const Text('Solo nombre y licencia. La asignación del viaje se hace luego desde el panel.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 28),
        TextField(controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre Completo *', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 16),
        TextField(controller: _licenseController,
            decoration: const InputDecoration(labelText: 'Número de Licencia *', prefixIcon: Icon(Icons.badge_outlined),
                hintText: 'Ej: LIC-12345')),
        const SizedBox(height: 32),
        SizedBox(
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _registerDriver,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.qr_code_2, color: Colors.black),
            label: Text(_isLoading ? 'REGISTRANDO...' : 'REGISTRAR Y GENERAR QR',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 3: Registrar Camión
// ─────────────────────────────────────────────────────────────
class _RegisterTruckTab extends StatefulWidget {
  const _RegisterTruckTab();

  @override
  State<_RegisterTruckTab> createState() => _RegisterTruckTabState();
}

class _RegisterTruckTabState extends State<_RegisterTruckTab> {
  final _plateController = TextEditingController();
  final _serialController = TextEditingController();
  final _fuelCapacityController = TextEditingController(text: '300');
  final _consumptionController = TextEditingController(text: '15');
  bool _isLoading = false;

  @override
  void dispose() {
    _plateController.dispose();
    _serialController.dispose();
    _fuelCapacityController.dispose();
    _consumptionController.dispose();
    super.dispose();
  }

  Future<void> _registerTruck() async {
    final plate = _plateController.text.trim();
    final capacity = double.tryParse(_fuelCapacityController.text.trim());
    final consumption = double.tryParse(_consumptionController.text.trim());

    if (plate.isEmpty || capacity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Placa y capacidad son obligatorias.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseService().createTruck(
        licensePlate: plate,
        engineSerial: _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
        fuelCapacity: capacity,
        consumptionRate: consumption ?? 15.0,
      );
      if (!mounted) return;
      _plateController.clear();
      _serialController.clear();
      _fuelCapacityController.text = '300';
      _consumptionController.text = '15';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camión $plate registrado ✓'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Registrar Nuevo Camión',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan)),
        const SizedBox(height: 24),
        TextField(controller: _plateController,
            decoration: const InputDecoration(labelText: 'Placa del Vehículo *', prefixIcon: Icon(Icons.pin_outlined))),
        const SizedBox(height: 16),
        TextField(controller: _serialController,
            decoration: const InputDecoration(labelText: 'Serial del Motor (opcional)', prefixIcon: Icon(Icons.settings_outlined))),
        const SizedBox(height: 16),
        TextField(controller: _fuelCapacityController, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacidad de Combustible (L) *',
                prefixIcon: Icon(Icons.local_gas_station_outlined), suffixText: 'L')),
        const SizedBox(height: 16),
        TextField(controller: _consumptionController, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Consumo Estimado',
                prefixIcon: Icon(Icons.speed_outlined), suffixText: 'L/100km')),
        const SizedBox(height: 32),
        SizedBox(
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _registerTruck,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.add_road, color: Colors.black),
            label: Text(_isLoading ? 'GUARDANDO...' : 'REGISTRAR CAMIÓN',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 32),
        const Divider(color: AppTheme.borderSlate),
        const SizedBox(height: 16),
        const Text('Camiones en Flota', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<List<Truck>>(
          stream: FirebaseService().getTrucksStream(),
          builder: (context, snapshot) {
            final trucks = snapshot.data ?? [];
            if (trucks.isEmpty) return const Text('No hay camiones registrados.', style: TextStyle(color: AppTheme.textMuted));
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trucks.length,
              separatorBuilder: (_, __) => const Divider(color: AppTheme.borderSlate),
              itemBuilder: (_, i) {
                final t = trucks[i];
                final isAssigned = t.assignedDriverId != null;
                final isMoving = t.status == 'moving';
                
                String statusText = 'Disponible';
                Color statusColor = AppTheme.primaryCyan;
                
                if (isMoving) {
                  statusText = 'En ruta';
                  statusColor = Colors.green;
                } else if (isAssigned) {
                  statusText = 'Asignado';
                  statusColor = Colors.orange;
                }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(Icons.local_shipping, color: statusColor),
                  ),
                  title: Text(t.licensePlate, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      isAssigned 
                          ? '${t.assignedDriverName ?? 'Conductor asignado'} • ${t.currentFuel.toStringAsFixed(0)}/${t.fuelCapacity.toStringAsFixed(0)} L'
                          : 'Sin asignar • ${t.currentFuel.toStringAsFixed(0)}/${t.fuelCapacity.toStringAsFixed(0)} L',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusText,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            );
          },
        ),
      ]),
    );
  }
}
