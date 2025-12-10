import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProductoService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://10.0.2.2:8000/api";

  Map<String, String> _headers({String? token}) {
    final headers = {"Content-Type": "application/json"};
    if (token != null) headers["Authorization"] = "Bearer $token";
    return headers;
  }

  // Obtener todos los productos (opcionalmente filtrados por categoría)
  Future<Map<String, dynamic>> getProductos(String token, {int? categoriaId}) async {
    try {
      var uri = Uri.parse("$baseUrl/inventario/productos/");
      
      // Agregar filtro de categoría si se proporciona
      if (categoriaId != null) {
        uri = uri.replace(queryParameters: {'categoria': categoriaId.toString()});
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

  // Obtener un producto específico
  Future<Map<String, dynamic>> getProducto(String token, int id) async {
    try {
      final uri = Uri.parse("$baseUrl/inventario/productos/$id/");
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
