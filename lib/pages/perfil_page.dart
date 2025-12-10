import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../widgets/app_drawer.dart';

class PerfilPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const PerfilPage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  Map<String, dynamic>? userData;
  late String token;
  bool isLoading = true;
  String? errorMessage;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      token = args;
      _loadProfile(token);
    } else {
      // Token faltante: ir al login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token no proporcionado. Por favor inicie sesión.'),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
    }
  }

  Future<void> _loadProfile(String token) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final res = await AuthService().getProfile(token);

    if (res['success']) {
      setState(() {
        userData = res['data'];
        isLoading = false;
        errorMessage = null;
      });
    } else {
      setState(() {
        isLoading = false;
        errorMessage = res['message'] ?? 'Error al obtener perfil';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage!)));
    }
  }

  Future<void> _logout(BuildContext context) async {
    // 🔔 Eliminar token FCM del backend antes de cerrar sesión
    try {
      await FirebaseService().unregisterToken();
      debugPrint('✅ Token FCM eliminado del backend');
    } catch (e) {
      debugPrint('⚠️ Error eliminando token FCM: $e');
    }
    
    // Eliminar tokens del storage
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_role');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = userData?['username'] ?? '';
    final email = userData?['email'] ?? '';
    final firstName = userData?['first_name'] ?? userData?['nombre'] ?? '';
    final lastName = userData?['last_name'] ?? userData?['apellido'] ?? '';

    // Calcular nombre a mostrar
    String displayName() {
      final f = firstName.trim();
      final l = lastName.trim();
      if (f.isNotEmpty || l.isNotEmpty) {
        return (f + (f.isNotEmpty && l.isNotEmpty ? ' ' : '') + l).trim();
      }
      if (username.isNotEmpty) return username;
      return '-';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text("Mi Perfil"),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      drawer: AppDrawer(userData: userData),
      body: Center(
        child: isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Cargando perfil...'),
                ],
              )
            : errorMessage != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $errorMessage', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadProfile(token),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.shade700,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    username.isNotEmpty
                        ? 'Bienvenido $username 🎉'
                        : 'Bienvenido',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Nombre: ${displayName()}'),
                  Text('Correo: ${email.isNotEmpty ? email : '-'}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Cerrar Sesión'),
                  ),
                ],
              ),
      ),
    );
  }
}
