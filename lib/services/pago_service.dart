import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PagoService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://10.0.2.2:8000/api";

  Map<String, String> _headers({String? token}) {
    final headers = {"Content-Type": "application/json"};
    if (token != null) headers["Authorization"] = "Bearer $token";
    return headers;
  }

  // Crear nota de venta desde carrito (igual que web)
  Future<Map<String, dynamic>> crearNotaDeVentaDesdeCarrito(String token, int carritoId) async {
    try {
      print('📄 Creando nota de venta desde carrito: $carritoId');
      final uri = Uri.parse("$baseUrl/transacciones/nota-venta/desde-carrito/");
      final response = await http.post(
        uri,
        headers: _headers(token: token),
        body: jsonEncode({'carrito_id': carritoId}),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        String errorMessage;
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? "Error ${response.statusCode}";
        } catch (e) {
          // Si no es JSON, usar el body como mensaje de error
          errorMessage = response.body.length > 100 
            ? "Error del servidor (${response.statusCode})" 
            : response.body;
        }
        return {"success": false, "message": errorMessage};
      }
    } catch (e) {
      print('❌ Error: $e');
      return {"success": false, "message": e.toString()};
    }
  }

  // Crear pago (igual que web)
  Future<Map<String, dynamic>> crearPago(String token, Map<String, dynamic> pagoData) async {
    try {
      print('💰 Creando registro de pago');
      final uri = Uri.parse("$baseUrl/transacciones/pagos/");
      final response = await http.post(
        uri,
        headers: _headers(token: token),
        body: jsonEncode(pagoData),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        String errorMessage;
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? "Error ${response.statusCode}";
        } catch (e) {
          errorMessage = response.body.length > 100 
            ? "Error del servidor (${response.statusCode})" 
            : response.body;
        }
        return {"success": false, "message": errorMessage};
      }
    } catch (e) {
      print('❌ Error: $e');
      return {"success": false, "message": e.toString()};
    }
  }

  // Marcar nota de venta como pagada (igual que web)
  Future<Map<String, dynamic>> marcarNotaDeVentaPagada(String token, int notaVentaId) async {
    try {
      print('✅ Marcando nota de venta como pagada');
      final uri = Uri.parse("$baseUrl/transacciones/nota-venta/$notaVentaId/marcar-pagada/");
      final response = await http.post(
        uri,
        headers: _headers(token: token),
        body: jsonEncode({}),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        String errorMessage;
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? "Error ${response.statusCode}";
        } catch (e) {
          errorMessage = response.body.length > 100 
            ? "Error del servidor (${response.statusCode})" 
            : response.body;
        }
        return {"success": false, "message": errorMessage};
      }
    } catch (e) {
      print('❌ Error: $e');
      return {"success": false, "message": e.toString()};
    }
  }

  // Crear historial de venta desde nota de venta (igual que web)
  Future<Map<String, dynamic>> crearHistorialDesdeNotaVenta(String token, int notaVentaId) async {
    try {
      print('📊 Registrando en historial de ventas');
      final uri = Uri.parse("$baseUrl/transacciones/historial-ventas/crear_desde_nota_venta/");
      final response = await http.post(
        uri,
        headers: _headers(token: token),
        body: jsonEncode({'nota_venta_id': notaVentaId}),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        String errorMessage;
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? "Error ${response.statusCode}";
        } catch (e) {
          errorMessage = response.body.length > 100 
            ? "Error del servidor (${response.statusCode})" 
            : response.body;
        }
        return {"success": false, "message": errorMessage};
      }
    } catch (e) {
      print('❌ Error: $e');
      return {"success": false, "message": e.toString()};
    }
  }

}
