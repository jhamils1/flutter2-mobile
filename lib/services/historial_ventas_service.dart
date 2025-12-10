import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HistorialVentasService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://10.0.2.2:8000/api";

  Map<String, String> _headers({String? token}) {
    final headers = {"Content-Type": "application/json"};
    if (token != null) headers["Authorization"] = "Bearer $token";
    return headers;
  }

  // Obtener todas las ventas (para admin/empleado)
  Future<Map<String, dynamic>> getHistorialVentas(String token, {Map<String, String>? filters}) async {
    try {
      var uri = Uri.parse("$baseUrl/transacciones/historial-ventas/");
      
      if (filters != null && filters.isNotEmpty) {
        uri = uri.replace(queryParameters: filters);
      }

      final response = await http.get(uri, headers: _headers(token: token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Obtener ventas de un cliente específico por CI
  Future<Map<String, dynamic>> getVentasPorCliente(String token, String ci) async {
    try {
      final uri = Uri.parse("$baseUrl/transacciones/historial-ventas/por_cliente/").replace(
        queryParameters: {'ci': ci}
      );

      print('DEBUG - URL llamada: $uri');
      final response = await http.get(uri, headers: _headers(token: token));
      print('DEBUG - Status code: ${response.statusCode}');
      print('DEBUG - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": "Error ${response.statusCode}: ${response.body}"};
      }
    } catch (e) {
      print('DEBUG - Exception: $e');
      return {"success": false, "message": e.toString()};
    }
  }

  // Obtener detalle de una venta específica
  Future<Map<String, dynamic>> getDetalleVenta(String token, int idVenta) async {
    try {
      final uri = Uri.parse("$baseUrl/transacciones/historial-ventas/$idVenta/");
      final response = await http.get(uri, headers: _headers(token: token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Obtener detalles de productos de una nota de venta
  Future<Map<String, dynamic>> getDetallesNotaVenta(String token, int notaVentaId) async {
    try {
      final uri = Uri.parse("$baseUrl/transacciones/detalle-nota-venta/").replace(
        queryParameters: {'nota_venta': notaVentaId.toString()}
      );

      final response = await http.get(uri, headers: _headers(token: token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}
