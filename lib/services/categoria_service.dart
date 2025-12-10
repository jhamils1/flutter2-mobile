import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CategoriaService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://10.0.2.2:8000/api";

  Map<String, String> _headers({String? token}) {
    final headers = {"Content-Type": "application/json"};
    if (token != null) headers["Authorization"] = "Bearer $token";
    return headers;
  }

  // Obtener todas las categorías
  Future<Map<String, dynamic>> getCategorias(String token) async {
    try {
      final uri = Uri.parse("$baseUrl/inventario/categorias/");
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
