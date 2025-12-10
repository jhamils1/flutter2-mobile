import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

class ReporteService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://10.0.2.2:8000/api";

  Map<String, String> _headers({String? token}) {
    final headers = {"Content-Type": "application/json"};
    if (token != null) headers["Authorization"] = "Bearer $token";
    return headers;
  }

  // Obtener ejemplos de consultas en lenguaje natural
  Future<Map<String, dynamic>> obtenerEjemplosNL(String token) async {
    try {
      final uri = Uri.parse("$baseUrl/analitica/reportes/ejemplos_nl/");
      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        final errorData = jsonDecode(response.body);
        return {"success": false, "message": errorData['error'] ?? "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Generar reporte usando lenguaje natural
  Future<Map<String, dynamic>> generarReporteNatural({
    required String token,
    required String consulta,
    String? nombre,
    required String formato,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/analitica/reportes/generar-natural/");
      
      // Preparar el body
      final Map<String, dynamic> body = {
        'consulta': consulta,
        'formato': formato,
      };
      
      // Solo agregar nombre si no es null y no está vacío
      if (nombre != null && nombre.isNotEmpty) {
        body['nombre'] = nombre;
      }
      
      print('🔵 Enviando request a: $uri');
      print('🔵 Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        uri,
        headers: _headers(token: token),
        body: jsonEncode(body),
      );

      print('🔵 Status Code: ${response.statusCode}');
      print('🔵 Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        // Intentar parsear el error
        String errorMessage = "Error ${response.statusCode}";
        Map<String, dynamic>? errorData;
        
        try {
          errorData = jsonDecode(response.body);
          
          // Intentar extraer el mensaje de error
          if (errorData?['error'] != null) {
            errorMessage = errorData!['error'];
          } else if (errorData?['errors'] != null) {
            // Si es un diccionario de errores del serializer
            final errors = errorData!['errors'];
            if (errors is Map) {
              // Concatenar todos los errores
              errorMessage = errors.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(', ');
            } else {
              errorMessage = errors.toString();
            }
          } else if (errorData?['detail'] != null) {
            errorMessage = errorData!['detail'];
          }
        } catch (e) {
          errorMessage = response.body;
        }
        
        return {
          "success": false, 
          "message": errorMessage,
          "details": errorData
        };
      }
    } catch (e) {
      print('❌ Error en generarReporteNatural: $e');
      return {"success": false, "message": e.toString()};
    }
  }

  // Descargar reporte
  Future<Map<String, dynamic>> descargarReporte(String token, int reporteId) async {
    try {
      print('📥 Descargando reporte $reporteId...');
      
      final uri = Uri.parse("$baseUrl/analitica/reportes/$reporteId/descargar/");
      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      print('📥 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Determinar extensión según Content-Type
        final contentType = response.headers['content-type'] ?? '';
        final extension = contentType.contains('pdf') ? 'pdf' : 'xlsx';
        
        print('📥 Content-Type: $contentType');
        print('📥 Extensión: $extension');
        
        // Crear nombre de archivo
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'reporte_${reporteId}_$timestamp.$extension';
        
        // Obtener la carpeta de descargas pública
        Directory? directory;
        
        if (Platform.isAndroid) {
          // Para Android, usar la carpeta de Downloads pública
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            // Fallback a la carpeta de la app
            directory = await getExternalStorageDirectory();
          }
        } else {
          // Para iOS y otros
          directory = await getApplicationDocumentsDirectory();
        }
        
        final filePath = '${directory!.path}/$fileName';
        
        print('📥 Guardando en: $filePath');
        
        // Escribir archivo
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        print('✅ Archivo guardado exitosamente');
        
        return {
          "success": true,
          "filePath": filePath,
          "fileName": fileName,
          "extension": extension,
          "message": "Reporte guardado en Downloads"
        };
      } else {
        print('❌ Error al descargar: ${response.statusCode}');
        return {"success": false, "message": "Error al descargar reporte: ${response.statusCode}"};
      }
    } catch (e) {
      print('❌ Excepción al descargar: $e');
      return {"success": false, "message": "Error: $e"};
    }
  }

  // Obtener historial de reportes
  Future<Map<String, dynamic>> obtenerHistorial(String token) async {
    try {
      final uri = Uri.parse("$baseUrl/analitica/reportes/historial/");
      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else {
        final errorData = jsonDecode(response.body);
        return {"success": false, "message": errorData['error'] ?? "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}
