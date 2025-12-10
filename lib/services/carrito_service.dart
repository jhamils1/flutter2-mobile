import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CarritoService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://10.0.2.2:8000/api";

  Map<String, String> _headers({String? token}) {
    final headers = {"Content-Type": "application/json"};
    if (token != null) headers["Authorization"] = "Bearer $token";
    return headers;
  }

  // Obtener todos los carritos
  Future<Map<String, dynamic>> getCarritos(String token) async {
    try {
      final uri = Uri.parse("$baseUrl/inventario/carritos/");
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

  // Obtener un carrito específico
  Future<Map<String, dynamic>> getCarrito(String token, int id) async {
    try {
      final uri = Uri.parse("$baseUrl/inventario/carritos/$id/");
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

  // Crear un nuevo carrito
  Future<Map<String, dynamic>> crearCarrito(String token, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse("$baseUrl/inventario/carritos/");
      final response = await http.post(
        uri,
        headers: _headers(token: token),
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {"success": true, "data": responseData};
      } else {
        return {"success": false, "message": "Error ${response.statusCode}: ${response.body}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Agregar producto al carrito (DetalleCarrito)
  Future<Map<String, dynamic>> agregarProducto(String token, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse("$baseUrl/inventario/detalles-carrito/");
      final response = await http.post(
        uri,
        headers: _headers(token: token),
        body: jsonEncode(data),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {"success": true, "data": responseData};
      } else {
        final errorData = jsonDecode(response.body);
        return {"success": false, "message": errorData['error'] ?? "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Actualizar cantidad de un producto en el carrito
  Future<Map<String, dynamic>> actualizarDetalle(String token, int detalleId, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse("$baseUrl/inventario/detalles-carrito/$detalleId/");
      final response = await http.put(
        uri,
        headers: _headers(token: token),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {"success": true, "data": responseData};
      } else {
        return {"success": false, "message": "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Eliminar producto del carrito
  Future<Map<String, dynamic>> eliminarDetalle(String token, int detalleId) async {
    try {
      final uri = Uri.parse("$baseUrl/inventario/detalles-carrito/$detalleId/");
      final response = await http.delete(uri, headers: _headers(token: token));

      if (response.statusCode == 204) {
        return {"success": true, "message": "Producto eliminado"};
      } else {
        return {"success": false, "message": "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}
