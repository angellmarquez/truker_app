import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseService().signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // No necesitamos navegar manualmente: main.dart usa authStateChanges()
      // y redirige automáticamente al HomeScreen cuando detecta la sesión.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo o contraseña incorrectos.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Abre la cámara para escanear el QR generado por el Admin.
  void _openQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppTheme.deepNavy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Escanea tu código QR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'El Admin te entregó este código al registrarte',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: MobileScanner(
                  onDetect: (capture) async {
                    final barcode = capture.barcodes.firstOrNull;
                    if (barcode?.rawValue == null) return;

                    Navigator.pop(context); // Cerrar el escáner

                    try {
                      // El QR contiene un JSON: {"email":"...","password":"...","token":"..."}
                      final data = jsonDecode(barcode!.rawValue!) as Map<String, dynamic>;
                      final email = data['email'] as String;
                      final password = data['password'] as String;
                      final token = data['token'] as String?;

                      setState(() => _isLoading = true);

                      if (token != null) {
                        // Validar y quemar token antes de entrar
                        await FirebaseService().verifyAndBurnToken(email, token);
                      }

                      await FirebaseService().signIn(email, password);
                      // main.dart detecta la sesión y redirige automáticamente
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Código QR inválido. Pide uno nuevo al Admin.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.deepNavy, Color(0xFF000000)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.local_shipping_rounded, size: 80, color: AppTheme.primaryCyan),
                    const SizedBox(height: 16),
                    Text(
                      'TruckFleet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const Text(
                      'Gestión Logística en Tiempo Real',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 48),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ingresa correo y contraseña.'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        _handleLogin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text('INICIAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    // Divisor con texto
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppTheme.borderSlate)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('o', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                        ),
                        const Expanded(child: Divider(color: AppTheme.borderSlate)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _openQRScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('ENTRAR CON CÓDIGO QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryCyan,
                        side: const BorderSide(color: AppTheme.primaryCyan),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
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
