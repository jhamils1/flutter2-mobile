import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/historial_ventas_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';

class HistorialVentasPage extends StatefulWidget {
  const HistorialVentasPage({super.key});

  @override
  State<HistorialVentasPage> createState() => _HistorialVentasPageState();
}

class _HistorialVentasPageState extends State<HistorialVentasPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final HistorialVentasService _ventasService = HistorialVentasService();
  final AuthService _authService = AuthService();
  
  List<dynamic> _ventas = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;
  String? _token;
  
  // Filtros
  final TextEditingController _searchController = TextEditingController();
  String? _estadoFiltro;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Verificar si hay argumentos de notificación
    Future.delayed(const Duration(milliseconds: 500), () {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('openDetailFor')) {
        final notaVentaId = int.tryParse(args['openDetailFor'].toString());
        if (notaVentaId != null && _ventas.isNotEmpty) {
          // Buscar la venta en la lista
          final venta = _ventas.firstWhere(
            (v) => v['nota_venta_id'] == notaVentaId,
            orElse: () => null,
          );
          if (venta != null) {
            _verDetalle(venta);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _token = await _storage.read(key: 'access_token');
      if (_token == null) {
        throw Exception('No hay sesión activa');
      }

      final profileRes = await _authService.getProfile(_token!);
      if (profileRes['success']) {
        _userData = profileRes['data'];
      }

      final filters = <String, String>{};
      if (_searchController.text.isNotEmpty) {
        filters['search'] = _searchController.text;
      }
      if (_estadoFiltro != null && _estadoFiltro!.isNotEmpty) {
        filters['estado'] = _estadoFiltro!;
      }

      final ventasRes = await _ventasService.getHistorialVentas(_token!, filters: filters);
      
      if (ventasRes['success']) {
        setState(() {
          _ventas = ventasRes['data'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception(ventasRes['message'] ?? 'Error al cargar ventas');
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
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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

  Future<void> _verDetalle(dynamic venta) async {
    final notaVentaId = venta['nota_venta'];
    
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
          title: Text('Venta ${venta['numero_venta']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cliente: ${venta['cliente_nombre'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('CI: ${venta['cliente_ci'] ?? '-'}'),
                Text('Fecha: ${_formatearFecha(venta['fecha_venta'])}'),
                Text('Estado: ${venta['estado_pago'] ?? '-'}'),
                Text('Método: ${venta['metodo_pago'] ?? '-'}'),
                const Divider(height: 20),
                const Text(
                  'Productos Vendidos:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...detalles.map((detalle) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.grey[50],
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
                      _formatearMoneda(venta['total']),
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

  double _calcularTotalRecaudado() {
    return _ventas.fold(0.0, (sum, venta) {
      try {
        return sum + double.parse(venta['total'].toString());
      } catch (e) {
        return sum;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Historial de Ventas'),
      ),
      drawer: AppDrawer(userData: _userData),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purple.shade300],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Total Ventas', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_ventas.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Recaudado', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_formatearMoneda(_calcularTotalRecaudado()), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _ventas.isEmpty
                        ? const Center(child: Text('No hay ventas'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _ventas.length,
                            itemBuilder: (context, index) {
                              final venta = _ventas[index];
                              final estado = venta['estado_pago'] ?? 'pendiente';
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text('N° ${venta['numero_venta']}'),
                                  subtitle: Text('${venta['cliente_nombre']} - ${_formatearFecha(venta['fecha_venta'])}'),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_formatearMoneda(venta['total']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getEstadoColor(estado).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(estado, style: TextStyle(fontSize: 10, color: _getEstadoColor(estado))),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _verDetalle(venta),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
