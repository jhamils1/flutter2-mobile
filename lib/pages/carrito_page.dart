import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/carrito_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final CarritoService _carritoService = CarritoService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _carritoActivo;
  List<dynamic> _detalles = [];
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

      _token = await _storage.read(key: 'access_token');
      if (_token == null) {
        throw Exception('No hay sesión activa');
      }

      // Obtener datos del usuario
      final profileRes = await _authService.getProfile(_token!);
      if (profileRes['success']) {
        _userData = profileRes['data'];
      }

      // Obtener carrito activo
      await _obtenerCarritoActivo();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _obtenerCarritoActivo() async {
    try {
      final carritosRes = await _carritoService.getCarritos(_token!);
      
      if (carritosRes['success']) {
        final carritos = carritosRes['data'] as List<dynamic>;
        final clienteId = _userData?['id'];
        
        _carritoActivo = carritos.firstWhere(
          (c) => c['estado'] == 'activo' && c['cliente'] == clienteId,
          orElse: () => null,
        );

        if (_carritoActivo != null) {
          final carritoRes = await _carritoService.getCarrito(_token!, _carritoActivo!['id']);
          if (carritoRes['success']) {
            _carritoActivo = carritoRes['data'];
            _detalles = _carritoActivo!['detalles'] ?? [];
          }
        }
      }
    } catch (e) {
      print('Error al obtener carrito: $e');
    }
  }

  Future<void> _actualizarCantidad(dynamic detalle, int nuevaCantidad) async {
    if (nuevaCantidad <= 0) return;

    try {
      final data = {
        'carrito': _carritoActivo!['id'],
        'producto': detalle['producto'],
        'cantidad': nuevaCantidad,
        'precio_unitario': detalle['precio_unitario'],
      };

      final result = await _carritoService.actualizarDetalle(_token!, detalle['id'], data);

      if (result['success']) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cantidad actualizada'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _eliminarProducto(dynamic detalle) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar producto'),
          content: const Text('¿Estás seguro de eliminar este producto del carrito?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final result = await _carritoService.eliminarDetalle(_token!, detalle['id']);

      if (result['success']) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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

  double _calcularTotal() {
    return _detalles.fold(0.0, (sum, detalle) {
      try {
        return sum + double.parse(detalle['subtotal'].toString());
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
        title: const Text('Mi Carrito'),
      ),
      drawer: AppDrawer(userData: _userData),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
              : _carritoActivo == null || _detalles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Tu carrito está vacío',
                            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/catalogo'),
                            icon: const Icon(Icons.shopping_bag),
                            label: const Text('Ver productos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _detalles.length,
                            itemBuilder: (context, index) {
                              final detalle = _detalles[index];
                              final producto = detalle['producto_info'];
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Imagen
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: producto['imagen'] != null && producto['imagen'] != ''
                                            ? Image.network(
                                                producto['imagen'],
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 80,
                                                    height: 80,
                                                    color: Colors.grey[300],
                                                    child: const Icon(Icons.image_not_supported),
                                                  );
                                                },
                                              )
                                            : Container(
                                                width: 80,
                                                height: 80,
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.shopping_bag),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Información
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              producto['nombre'] ?? 'Producto',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatearMoneda(detalle['precio_unitario']),
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () => _actualizarCantidad(
                                                    detalle,
                                                    detalle['cantidad'] - 1,
                                                  ),
                                                  icon: const Icon(Icons.remove_circle_outline),
                                                  color: Colors.red,
                                                  constraints: const BoxConstraints(),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  child: Text(
                                                    '${detalle['cantidad']}',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => _actualizarCantidad(
                                                    detalle,
                                                    detalle['cantidad'] + 1,
                                                  ),
                                                  icon: const Icon(Icons.add_circle_outline),
                                                  color: Colors.green,
                                                  constraints: const BoxConstraints(),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Subtotal y eliminar
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatearMoneda(detalle['subtotal']),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          IconButton(
                                            onPressed: () => _eliminarProducto(detalle),
                                            icon: const Icon(Icons.delete_outline),
                                            color: Colors.red,
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Total y botón de pago
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _formatearMoneda(_calcularTotal()),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/pago',
                                      arguments: {
                                        'id': _carritoActivo!['id'],
                                        'total_carrito': _calcularTotal(),
                                        'total_items': _detalles.length,
                                      },
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Proceder al Pago',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}
