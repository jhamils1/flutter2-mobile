import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/historial_ventas_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';

class MisComprobantesPage extends StatefulWidget {
  const MisComprobantesPage({super.key});

  @override
  State<MisComprobantesPage> createState() => _MisComprobantesPageState();
}

class _MisComprobantesPageState extends State<MisComprobantesPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final HistorialVentasService _ventasService = HistorialVentasService();
  final AuthService _authService = AuthService();
  
  List<dynamic> _comprobantes = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Obtener token
      _token = await _storage.read(key: 'access_token');
      if (_token == null) {
        throw Exception('No hay sesión activa');
      }

      // Obtener datos del usuario para sacar el CI
      final profileRes = await _authService.getProfile(_token!);
      if (!profileRes['success']) {
        throw Exception('No se pudo obtener el perfil');
      }

      _userData = profileRes['data'];
      final ci = _userData?['ci'];

      print('DEBUG - Usuario data: $_userData');
      print('DEBUG - CI del cliente: $ci');

      if (ci == null) {
        throw Exception('No se encontró el CI del cliente');
      }

      // Obtener comprobantes del cliente
      final ventasRes = await _ventasService.getVentasPorCliente(_token!, ci);
      print('DEBUG - Respuesta ventas: $ventasRes');
      
      if (ventasRes['success']) {
        // El endpoint devuelve {cliente_ci, total_ventas, ventas: [...]}
        final responseData = ventasRes['data'];
        List<dynamic> ventasList = [];
        
        if (responseData is Map<String, dynamic>) {
          // Si es un mapa, extraer el array 'ventas'
          ventasList = List<dynamic>.from(responseData['ventas'] ?? []);
        } else if (responseData is List) {
          // Si ya es una lista, usarla directamente
          ventasList = responseData;
        }
        
        setState(() {
          _comprobantes = ventasList;
          _isLoading = false;
        });
      } else {
        throw Exception(ventasRes['message'] ?? 'Error al cargar comprobantes');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return '-';
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return fecha;
    }
  }

  String _formatearMoneda(dynamic monto) {
    try {
      final valor = double.parse(monto.toString());
      return 'Bs. ${valor.toStringAsFixed(2)}';
    } catch (e) {
      return 'Bs. 0.00';
    }
  }

  Color _getEstadoColor(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'completado':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'fallido':
        return Colors.red;
      case 'anulado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _verDetalle(dynamic comprobante) async {
    final notaVentaId = comprobante['nota_venta'];
    
    if (notaVentaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener el ID de la nota de venta')),
      );
      return;
    }

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Obtener detalles de productos
      final detallesRes = await _ventasService.getDetallesNotaVenta(_token!, notaVentaId);
      
      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      if (!detallesRes['success']) {
        throw Exception(detallesRes['message'] ?? 'Error al cargar detalles');
      }

      final detalles = detallesRes['data'] as List<dynamic>;

      if (!mounted) return;

      // Mostrar diálogo con detalles
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Comprobante ${comprobante['numero_venta']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetalleRow('Número:', comprobante['numero_venta']),
                _buildDetalleRow('Fecha:', _formatearFecha(comprobante['fecha_venta'])),
                _buildDetalleRow('Estado:', comprobante['estado_pago'] ?? '-'),
                _buildDetalleRow('Método de Pago:', comprobante['metodo_pago'] ?? '-'),
                if (comprobante['referencia_pago'] != null)
                  _buildDetalleRow('Referencia:', comprobante['referencia_pago']),
                const Divider(height: 20),
                const Text(
                  'Productos Comprados:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...detalles.map((detalle) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detalle['producto_nombre'] ?? 'Producto',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Cantidad: ${detalle['cantidad']}'),
                            Text(_formatearMoneda(detalle['precio_unitario'])),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              _formatearMoneda(detalle['total']),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )).toList(),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      _formatearMoneda(comprobante['total']),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar detalles: $e')),
        );
      }
    }
  }

  Widget _buildDetalleRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? '-'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Mis Comprobantes'),
      ),
      drawer: AppDrawer(userData: _userData),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando comprobantes...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _comprobantes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No tienes comprobantes aún',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comprobantes.length,
                        itemBuilder: (context, index) {
                          final comprobante = _comprobantes[index];
                          final estado = comprobante['estado_pago'] ?? 'pendiente';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _verDetalle(comprobante),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'N° ${comprobante['numero_venta']}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getEstadoColor(estado).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _getEstadoColor(estado),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            estado.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _getEstadoColor(estado),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatearFecha(comprobante['fecha_venta']),
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.payment, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          comprobante['metodo_pago'] ?? 'N/A',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _formatearMoneda(comprobante['total']),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
