import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://10.0.2.2:8000/api";

  String _shortBody(String body, [int max = 400]) {
    if (body.length <= max) return body;
    return '${body.substring(0, max)}... (truncated)';
  }

  String _userMessageForSnippet(String snippet, int status) {
    final lower = snippet.toLowerCase();
    if (lower.contains('<!doctype') || lower.contains('<html')) {
      return 'El servidor devolvió HTML (posible redirect a página de login o error). Verifica BASE_URL y token. HTTP $status.';
    }
    return 'HTTP $status: $snippet';
  }

  String _formatErrorJson(dynamic data) {
    // Convierte estructuras JSON de error en mensajes legibles
    try {
      if (data is Map) {
        final parts = <String>[];
        data.forEach((key, value) {
          if (value is List) {
            parts.add('$key: ${value.join('; ')}');
          } else if (value is Map) {
            parts.add('$key: ${value.toString()}');
          } else {
            parts.add('$key: $value');
          }
        });
        return parts.join(' | ');
      }
      // lista u otro
      if (data is List) return data.join('; ');
      return data.toString();
    } catch (e) {
      return data.toString();
    }
  }

  // 🔹 Headers con o sin token
  Map<String, String> _headers({String? token}) {
    final headers = {"Content-Type": "application/json"};
    if (token != null) headers["Authorization"] = "Bearer $token";
    return headers;
  }

  // 🔹 POST genérico con manejo de errores
  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body,
      {String? token}) async {
    try {
      final url = Uri.parse("$baseUrl/$endpoint");
      final response = await http.post(url, headers: _headers(token: token), body: jsonEncode(body));

      final contentType = response.headers['content-type'] ?? '';

      // Solo intentar decodificar JSON si el servidor indicó JSON
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (contentType.contains('application/json')) {
          try {
            final data = jsonDecode(response.body);
            return {"success": true, "data": data};
          } catch (e) {
            // Respuesta 2xx pero no JSON válido
            final snippet = _shortBody(response.body);
            print('AuthService POST $url - 2xx pero no JSON. status=${response.statusCode} body="$snippet"');
            return {"success": false, "message": _userMessageForSnippet(snippet, response.statusCode)};
          }
        } else {
          // 2xx pero no JSON
          final snippet = _shortBody(response.body);
          print('AuthService POST $url - 2xx no-json. status=${response.statusCode} body="$snippet"');
          return {"success": false, "message": _userMessageForSnippet(snippet, response.statusCode)};
        }
      } else {
        // Error - tratar de extraer mensaje desde JSON si es posible
        if (contentType.contains('application/json')) {
          try {
            final data = jsonDecode(response.body);
            final msg = data["detail"] ?? _formatErrorJson(data);
            return {"success": false, "message": msg, "errors": data};
          } catch (_) {
            final snippet = _shortBody(response.body);
            print('AuthService POST $url - error no-json. status=${response.statusCode} body="$snippet"');
            return {"success": false, "message": _userMessageForSnippet(snippet, response.statusCode)};
          }
        } else {
          final snippet = response.body.isNotEmpty ? _shortBody(response.body) : 'No hay body';
          print('AuthService POST $url - error no-json. status=${response.statusCode} body="$snippet"');
          return {"success": false, "message": _userMessageForSnippet(snippet, response.statusCode)};
        }
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // 🔹 GET genérico con manejo de errores
  Future<Map<String, dynamic>> _get(String endpoint, {String? token}) async {
    try {
      final url = Uri.parse("$baseUrl/$endpoint");
      final response = await http.get(url, headers: _headers(token: token));
      final contentType = response.headers['content-type'] ?? '';

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (contentType.contains('application/json')) {
          try {
            final data = jsonDecode(response.body);
            return {"success": true, "data": data};
          } catch (e) {
            final snippet = _shortBody(response.body);
            print('AuthService GET $url - 2xx pero no JSON. status=${response.statusCode} body="$snippet"');
            return {"success": false, "message": _userMessageForSnippet(snippet, response.statusCode)};
          }
        } else {
          final snippet = _shortBody(response.body);
          print('AuthService GET $url - 2xx no-json. status=${response.statusCode} body="$snippet"');
          return {"success": false, "message": _userMessageForSnippet(snippet, response.statusCode)};
        }
      } else {
        if (contentType.contains('application/json')) {
          try {
            final data = jsonDecode(response.body);
            final msg = data["detail"] ?? _formatErrorJson(data);
            return {"success": false, "message": msg, "errors": data};
          } catch (_) {
            final snippet = _shortBody(response.body);
            print('AuthService GET $url - error no-json. status=${response.statusCode} body="$snippet"');
            return {"success": false, "message": _userMessageForSnippet(snippet, response.statusCode)};
          }
        } else {
          final snippet = response.body.isNotEmpty ? _shortBody(response.body) : 'No hay body';
          print('AuthService GET $url - error no-json. status=${response.statusCode} body="$snippet"');
          return {"success": false, "message": _userMessageForSnippet(snippet, response.statusCode)};
        }
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // 🔹 Login
  Future<Map<String, dynamic>> login(String username, String password) {
    return _post("token/", {"username": username, "password": password});
  }

  // 🔹 Registrar usuario
  Future<Map<String, dynamic>> register(
      String username, String email, String password, String password2) {
    return _post("register/", {
      "username": username,
      "email": email,
      "password": password,
      "password2": password2
    });
  }

  // 🔹 Obtener perfil
  Future<Map<String, dynamic>> getProfile(String token) async {
    // El backend expone endpoints: 'clientes/profile/' y 'empleados/profile/' bajo /api/
    // Intentamos primero cliente, y si falla intentamos empleado.
    final resCliente = await _get("clientes/profile/", token: token);
    if (resCliente['success']) return resCliente;

    final resEmpleado = await _get("empleados/profile/", token: token);
    if (resEmpleado['success']) return resEmpleado;

    // Como último recurso, usar el endpoint genérico /me/ para administradores u otros roles
    final resMe = await _get("me/", token: token);
    if (resMe['success']) return resMe;

    // Si ninguno funciona, devolver error
    return {"success": false, "message": "No se pudo obtener el perfil"};
  }

  // 🔹 Obtener información del usuario autenticado (role, permisos, etc.)
  Future<Map<String, dynamic>> getMe(String token) async {
    // Intentar obtener perfil de cliente o empleado
    return await getProfile(token);
  }

  // 🔹 Cambiar contraseña
  Future<Map<String, dynamic>> changePassword(
      String token, String oldPassword, String newPassword) {
    return _post(
      "change-password/",
      {"old_password": oldPassword, "new_password": newPassword},
      token: token,
    );
  }

  // 🔹 Actualizar perfil (nuevo método)
  Future<Map<String, dynamic>> updateProfile(
      String token, String firstName, String lastName, String email) {
    // El backend usa 'cliente/profile/' (PUT/PATCH) para actualizar perfil de cliente
    return _post(
      "cliente/profile/",
      {
        "first_name": firstName,
        "last_name": lastName,
        "email": email,
      },
      token: token,
    );
  }
}
