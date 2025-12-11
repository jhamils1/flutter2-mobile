import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 🔥 Función para manejar mensajes en segundo plano (debe estar fuera de la clase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Solo inicializar si no está ya inicializado
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  debugPrint('📩 Mensaje en segundo plano: ${message.messageId}');
  debugPrint('Título: ${message.notification?.title}');
  debugPrint('Cuerpo: ${message.notification?.body}');
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  // Callback para navegación
  Function(String route, {Map<String, dynamic>? arguments})? onNavigate;
  
  // Flag para evitar múltiples inicializaciones
  bool _isInitialized = false;

  // 🔧 Inicializar Firebase y notificaciones
  Future<void> initialize() async {
    // Si ya está inicializado, no hacer nada
    if (_isInitialized) {
      debugPrint('⚠️ FirebaseService ya está inicializado, omitiendo...');
      return;
    }
    
    debugPrint('🚀 Iniciando FirebaseService...');
    
    try {
      // 1️⃣ Solicitar permisos de notificación
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Permisos de notificación concedidos');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ Permisos provisionales concedidos');
      } else {
        debugPrint('❌ Permisos de notificación denegados');
        return;
      }

      // 2️⃣ Configurar notificaciones locales
      await _initializeLocalNotifications();

      // 3️⃣ Obtener token FCM con reintentos (especialmente para Xiaomi)
      int maxRetries = 5;
      for (int i = 0; i < maxRetries; i++) {
        try {
          // Esperar más tiempo en dispositivos Xiaomi
          if (i > 0) {
            await Future.delayed(Duration(seconds: 3 + i));
          }
          
          // Intentar eliminar token anterior si existe
          if (i > 0) {
            try {
              await _messaging.deleteToken();
              debugPrint('🗑️ Token anterior eliminado, solicitando nuevo...');
              await Future.delayed(Duration(seconds: 2));
            } catch (e) {
              debugPrint('⚠️ No se pudo eliminar token anterior: $e');
            }
          }
          
          _fcmToken = await _messaging.getToken();
          if (_fcmToken != null && _fcmToken!.isNotEmpty) {
            debugPrint('🔑 FCM Token obtenido: $_fcmToken');
            debugPrint('✅ Token length: ${_fcmToken!.length}');
            break;
          } else {
            debugPrint('⚠️ Token FCM es null o vacío, reintentando... (${i + 1}/$maxRetries)');
          }
        } catch (e) {
          debugPrint('❌ Error obteniendo token (intento ${i + 1}/$maxRetries): $e');
          if (i == maxRetries - 1) {
            debugPrint('⚠️ No se pudo obtener token FCM después de $maxRetries intentos');
            debugPrint('   Esto puede deberse a:');
            debugPrint('   - Restricciones de Xiaomi/MIUI');
            debugPrint('   - Google Play Services deshabilitado');
            debugPrint('   - Problemas de conectividad');
            debugPrint('   - Restricciones de batería/autoarranque');
            debugPrint('');
            debugPrint('   🔧 SOLUCIÓN para Xiaomi:');
            debugPrint('   1. Activar Autoarranque para esta app');
            debugPrint('   2. Quitar restricciones de batería');
            debugPrint('   3. Bloquear app en recientes (candado)');
            debugPrint('   4. Activar permisos para Google Play Services');
          }
        }
      }

      // 4️⃣ Configurar listeners
      _setupMessageHandlers();

      // 5️⃣ Configurar handler de mensajes en segundo plano
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // 6️⃣ Enviar token al backend (si el usuario está logueado)
      await _sendTokenToBackend();
      
      // Marcar como inicializado
      _isInitialized = true;
      debugPrint('✅ FirebaseService inicializado completamente');
    } catch (e) {
      debugPrint('❌ Error inicializando Firebase: $e');
    }
  }

  // 🔔 Inicializar notificaciones locales (para mostrar cuando la app está abierta)
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('📱 Notificación tocada: ${response.payload}');
        // Manejar navegación según el payload
        if (response.payload != null) {
          _handleNotificationNavigation(response.payload!);
        }
      },
    );

    // Crear canal de notificación para Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // ID
      'Notificaciones importantes', // Nombre
      description: 'Canal para notificaciones importantes de SmartSales',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 📨 Configurar listeners de mensajes
  void _setupMessageHandlers() {
    // Cuando la app está en PRIMER PLANO
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Mensaje recibido en primer plano');
      debugPrint('Título: ${message.notification?.title}');
      debugPrint('Cuerpo: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');

      // Mostrar notificación local
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Cuando el usuario toca la notificación y la app estaba en SEGUNDO PLANO
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Notificación tocada (app en segundo plano)');
      debugPrint('Data: ${message.data}');
      _handleNotificationNavigation(jsonEncode(message.data));
    });

    // Verificar si la app se abrió desde una notificación
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📭 App abierta desde notificación');
        debugPrint('Data: ${message.data}');
        _handleNotificationNavigation(jsonEncode(message.data));
      }
    });
  }

  // 🧭 Manejar navegación desde notificaciones
  void _handleNotificationNavigation(String payload) {
    try {
      final data = jsonDecode(payload);
      final type = data['type'];
      
      debugPrint('🧭 Manejando navegación de notificación tipo: $type');
      debugPrint('📊 Data completa: $data');
      
      if (type == 'nueva_venta') {
        final notaVentaId = data['nota_venta_id'];
        
        debugPrint('📊 Intentando navegar a historial de ventas con ID: $notaVentaId');
        
        // Usar callback de navegación si está disponible
        if (onNavigate != null) {
          debugPrint('✅ Usando callback de navegación');
          onNavigate!('/historial-ventas', arguments: {
            'openDetailFor': notaVentaId,
          });
        } else {
          debugPrint('⚠️ Callback de navegación no disponible, guardando para después');
          _pendingNotificationData = {
            'type': type,
            'nota_venta_id': notaVentaId,
          };
        }
      } else if (type == 'stock_bajo') {
        final productoNombre = data['producto_nombre'];
        final stockActual = data['stock_actual'];
        
        debugPrint('📦 Stock bajo detectado: $productoNombre (Stock: $stockActual)');
        
        // Navegar al catálogo
        if (onNavigate != null) {
          debugPrint('✅ Navegando al catálogo');
          onNavigate!('/catalogo', arguments: {
            'highlightProducto': data['producto_id'],
          });
        } else {
          debugPrint('⚠️ Callback de navegación no disponible, guardando para después');
          _pendingNotificationData = {
            'type': type,
            'producto_id': data['producto_id'],
            'producto_nombre': productoNombre,
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Error manejando navegación: $e');
    }
  }

  // Datos de notificación pendiente
  Map<String, dynamic>? _pendingNotificationData;
  Map<String, dynamic>? get pendingNotificationData => _pendingNotificationData;
  
  void clearPendingNotification() {
    _pendingNotificationData = null;
  }

  // 🔔 Mostrar notificación local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'Notificaciones importantes',
      channelDescription: 'Canal para notificaciones importantes de SmartSales',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'SmartSales',
      message.notification?.body ?? '',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // 📤 Enviar token al backend
  Future<void> _sendTokenToBackend() async {
    debugPrint('🔄 Intentando enviar token FCM al backend...');
    
    if (_fcmToken == null) {
      debugPrint('⚠️ No hay token FCM para enviar');
      return;
    }

    debugPrint('🔑 Token FCM disponible: ${_fcmToken!.substring(0, 30)}...');

    try {
      // Verificar si el usuario está logueado
      String? token = await _storage.read(key: 'access_token');
      if (token == null) {
        debugPrint('⚠️ Usuario no logueado, no se envía token FCM');
        return;
      }

      debugPrint('✅ Token de autenticación encontrado');

      // Obtener la URL base desde .env
      String baseUrl = dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:8000';
      // Asegurarse de que no termine con /
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      final url = Uri.parse('$baseUrl/device-tokens/');
      
      debugPrint('📍 Enviando a: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'token': _fcmToken,
          'platform': 'android',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Token FCM enviado al backend exitosamente');
      } else {
        debugPrint('❌ Error enviando token: ${response.statusCode}');
        debugPrint('Respuesta: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error enviando token al backend: $e');
    }
  }

  // 🔄 Actualizar token cuando cambia
  void onTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      debugPrint('🔄 Token FCM actualizado: $newToken');
      _sendTokenToBackend();
    });
  }

  // 🚀 Llamar después del login
  Future<void> registerTokenAfterLogin() async {
    await _sendTokenToBackend();
  }

  // 🚪 Eliminar token al hacer logout
  Future<void> unregisterToken() async {
    if (_fcmToken == null) return;

    try {
      String? token = await _storage.read(key: 'access_token');
      if (token == null) return;

      // Obtener la URL base desde .env
      String baseUrl = dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:8000';
      // Asegurarse de que no termine con /
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      final url = Uri.parse('$baseUrl/device-tokens/unregister/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'token': _fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Token FCM eliminado del backend');
      }
    } catch (e) {
      debugPrint('❌ Error eliminando token: $e');
    }
  }
}
