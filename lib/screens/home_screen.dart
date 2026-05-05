import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'monitoring_screen.dart';
import 'reports_screen.dart';
import 'admin_screen.dart';
import 'driver_map_screen.dart'; // Añadido el import

class HomeScreen extends StatefulWidget {
  static final GlobalKey<_HomeScreenState> homeKey = GlobalKey<_HomeScreenState>();
  HomeScreen() : super(key: homeKey);

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  static void setIndex(int index) {
    homeKey.currentState?.setIndex(index);
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  UserProfile? _profile;

  void setIndex(int index) {
    setState(() => _selectedIndex = index);
  }

  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await FirebaseService().getUserProfile(user.uid);
        if (mounted) {
          setState(() {
            _profile = profile;
            _isError = false;
          });
        }
      } else {
        if (mounted) setState(() => _isError = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    // Solo llamamos signOut(). El StreamBuilder en main.dart
    // detecta el cambio y redirige al Login automáticamente.
    await FirebaseService().signOut();
  }

  List<Widget> get _adminScreens => [
    MonitoringScreen(),
    const ReportsScreen(),
    const AdminScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                const Text('No se pudo cargar tu perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _handleSignOut,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.black),
                  child: const Text('CERRAR SESIÓN'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)));
    }

    // Si es conductor, mostrar la interfaz de conductor
    if (_profile!.role == UserRole.driver) {
      return const DriverMapScreen();
    }

    // Si es admin, mostrar el panel de control con tabs
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _adminScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Admin'),
        ],
      ),
    );
  }
}
