import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'pages/login_page.dart';
import 'pages/perfil_page.dart';
import 'pages/funcion1_page.dart';
import 'pages/funcion2_page.dart';
import 'pages/funcion3_page.dart';
import 'pages/mis_comprobantes_page.dart';
import 'pages/catalogo_page.dart';
import 'pages/carrito_page.dart';
import 'pages/pago_page.dart';
import 'pages/pago_exitoso_page.dart';
import 'pages/reportes_page.dart';
import 'pages/historial_ventas_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Carga las variables del archivo .env con manejo de errores
  try {
    await dotenv.load(fileName: ".env");
    
    // 🔹 NO inicializamos Stripe SDK ya que usamos la API REST del backend
    // Esto evita los overlays de debug de Stripe en la UI
    debugPrint('✅ Variables de entorno cargadas');
  } catch (e) {
    debugPrint("❌ Error cargando .env: $e");
    // Continuar sin .env, usar valores por defecto
  }

  // 🔥 Inicializar Firebase (solo si no está inicializado)
  try {
    // Verificar si Firebase ya está inicializado
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase inicializado');
    } else {
      debugPrint('✅ Firebase ya estaba inicializado');
    }
  } catch (e) {
    // Si falla porque ya existe, continuar igualmente
    if (e.toString().contains('duplicate-app')) {
      debugPrint('⚠️ Firebase ya estaba inicializado (hot restart)');
    } else {
      debugPrint('❌ Error inicializando Firebase: $e');
    }
  }

  // 🔔 Inicializar servicio de notificaciones (separado para evitar conflictos)
  try {
    await FirebaseService().initialize();
    FirebaseService().onTokenRefresh(); // Escuchar cambios de token
  } catch (e) {
    debugPrint('❌ Error inicializando FirebaseService: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDark = false;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupNavigationCallback();
    _checkPendingNotifications();
  }

  // 🔧 Configurar callback de navegación para FirebaseService
  void _setupNavigationCallback() {
    FirebaseService().onNavigate = (String route, {Map<String, dynamic>? arguments}) {
      debugPrint('🧭 Navegando a: $route con argumentos: $arguments');
      navigatorKey.currentState?.pushNamed(route, arguments: arguments);
    };
  }

  // 🔔 Verificar si hay notificaciones pendientes
  void _checkPendingNotifications() {
    Future.delayed(const Duration(seconds: 2), () {
      final notificationData = FirebaseService().pendingNotificationData;
      if (notificationData != null) {
        debugPrint('📱 Notificación pendiente encontrada: $notificationData');
        
        if (notificationData['type'] == 'nueva_venta') {
          // Navegar al historial de ventas
          navigatorKey.currentState?.pushNamed('/historial-ventas', 
            arguments: {
              'openDetailFor': notificationData['nota_venta_id'],
            }
          );
          FirebaseService().clearPendingNotification();
        } else if (notificationData['type'] == 'stock_bajo') {
          // Navegar al catálogo
          navigatorKey.currentState?.pushNamed('/catalogo', 
            arguments: {
              'highlightProducto': notificationData['producto_id'],
            }
          );
          FirebaseService().clearPendingNotification();
        }
      }
    });
  }

  // 🔹 Cambia entre tema claro y oscuro
  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Demo',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      // 🔹 Tema claro
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        brightness: Brightness.light,
        useMaterial3: true,
      ),

      // 🔹 Tema oscuro
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,

      // 🔹 Rutas de la aplicación
      initialRoute: "/",
      routes: {
        "/": (context) =>
            LoginPage(onToggleTheme: _toggleTheme, isDark: _isDark),
        "/perfil": (context) =>
            PerfilPage(onToggleTheme: _toggleTheme, isDark: _isDark),
        "/funcion1": (context) => const Funcion1Page(),
        "/funcion2": (context) => const Funcion2Page(),
        "/funcion3": (context) => const Funcion3Page(),
        "/mis-comprobantes": (context) => const MisComprobantesPage(),
        "/catalogo": (context) => const CatalogoPage(),
        "/carrito": (context) => const CarritoPage(),
        "/pago-exitoso": (context) => const PagoExitosoPage(),
        "/reportes": (context) => const ReportesPage(),
        "/historial-ventas": (context) => const HistorialVentasPage(),
      },
      onGenerateRoute: (settings) {
        // Ruta dinámica para pago que recibe argumentos
        if (settings.name == '/pago') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PagoPage(carritoData: args),
          );
        }
        return null;
      },
    );
  }
}
