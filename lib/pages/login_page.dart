import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../widgets/custom_text_field.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const LoginPage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final user = _userController.text;
      final pass = _passController.text;

      // 🔹 Usando la versión final de AuthService
      final result = await _authService.login(user, pass);

      if (result['success']) {
        final access = result['data']['access'];
        // Debug: imprimir token en consola para verificar que llega correctamente
        print('Login successful - access token: $access');

        // 🔹 GUARDAR TOKEN EN SECURE STORAGE
        await _storage.write(key: 'access_token', value: access);
        if (result['data']['refresh'] != null) {
          await _storage.write(
            key: 'refresh_token',
            value: result['data']['refresh'],
          );
        }
        print('Token guardado en secure storage');

        // 🔹 OBTENER ROL DEL USUARIO
        try {
          final meResult = await _authService.getMe(access);
          if (meResult['success']) {
            final roleData = meResult['data'];
            print('Datos de usuario: $roleData');
            
            // Obtener el rol del usuario
            String? userRole;
            if (roleData['role'] != null) {
              userRole = roleData['role'].toString().toLowerCase();
            } else if (roleData['groups'] != null && roleData['groups'] is List && (roleData['groups'] as List).isNotEmpty) {
              userRole = roleData['groups'][0].toString().toLowerCase();
            } else if (roleData['is_staff'] == true || roleData['is_superuser'] == true) {
              userRole = 'administrador';
            } else {
              userRole = 'cliente';
            }
            
            // Guardar rol en secure storage
            await _storage.write(key: 'user_role', value: userRole);
            print('Rol de usuario guardado: $userRole');
          } else {
            // Si no se puede obtener el rol, asumir cliente
            await _storage.write(key: 'user_role', value: 'cliente');
            print('No se pudo obtener rol, asignando "cliente" por defecto');
          }
        } catch (e) {
          print('Error al obtener rol: $e');
          // Si hay error, asumir cliente
          await _storage.write(key: 'user_role', value: 'cliente');
        }

        // 🔔 Registrar token FCM después del login exitoso
        try {
          await FirebaseService().registerTokenAfterLogin();
          print('✅ Token FCM registrado en el backend');
        } catch (e) {
          print('⚠️ Error registrando token FCM: $e');
          // No es crítico, continuar con el flujo
        }

        Navigator.pushReplacementNamed(context, "/perfil", arguments: access);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al iniciar sesión'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text("Iniciar Sesión"),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  32,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 👇 Logo en la parte superior (más pequeño en pantallas pequeñas)
                  SizedBox(
                    height: MediaQuery.of(context).size.height > 600
                        ? 150
                        : 100,
                    width: MediaQuery.of(context).size.height > 600 ? 150 : 100,
                    child: Image.asset("assets/images/logo7.png"),
                  ),
                  const SizedBox(height: 24),

                  CustomTextField(
                    controller: _userController,
                    label: "Usuario",
                    prefixIcon: Icons.person,
                    filled: true,
                    validator: (value) =>
                        value!.isEmpty ? "Ingrese su usuario" : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passController,
                    label: "Contraseña",
                    isPassword: true,
                    prefixIcon: Icons.lock,
                    filled: true,
                    validator: (value) =>
                        value!.isEmpty ? "Ingrese su contraseña" : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.shade700,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Ingresar"),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
