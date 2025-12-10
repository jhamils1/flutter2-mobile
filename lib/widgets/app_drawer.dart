import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/firebase_service.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic>? userData;
  
  const AppDrawer({
    super.key,
    this.userData,
  });

  Future<void> _logout(BuildContext context) async {
    // 🔔 Eliminar token FCM del backend antes de cerrar sesión
    try {
      await FirebaseService().unregisterToken();
      print('✅ Token FCM eliminado del backend');
    } catch (e) {
      print('⚠️ Error eliminando token FCM: $e');
    }
    
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión cerrada correctamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = userData?['nombre'] ?? userData?['username'] ?? 'Usuario';
    final apellido = userData?['apellido'] ?? '';
    final email = userData?['email'] ?? '';
    final role = userData?['role'] ?? 'usuario';

    return Drawer(
      child: Column(
        children: [
          // Header con información del usuario
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Colors.deepPurple,
            ),
            accountName: Text(
              '$nombre $apellido'.trim(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            otherAccountsPictures: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Opciones del menú
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Inicio'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                
                // Opciones para CLIENTES
                if (role.toLowerCase() == 'cliente') ...[
                  ListTile(
                    leading: const Icon(Icons.shopping_bag),
                    title: const Text('Catálogo'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/catalogo');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.shopping_cart),
                    title: const Text('Mi Carrito'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/carrito');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('Mis Comprobantes'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/mis-comprobantes');
                    },
                  ),
                ],
                
                // Opciones para ADMINISTRADOR/EMPLEADO
                if (role.toLowerCase() == 'administrador' || role.toLowerCase() == 'empleado') ...[
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Historial de Ventas'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/historial-ventas');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.assessment),
                    title: const Text('Reportes'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/reportes');
                    },
                  ),
                ],
              ],
            ),
          ),

          // Cerrar sesión en la parte inferior
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _logout(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
