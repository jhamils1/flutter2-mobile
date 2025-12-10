import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/carrito_service.dart';

class ProductoDetallePage extends StatefulWidget {
  final Map<String, dynamic> producto;
  final Map<String, dynamic>? carritoActivo;

  const ProductoDetallePage({
    super.key,
    required this.producto,
    this.carritoActivo,
  });

  @override
  State<ProductoDetallePage> createState() => _ProductoDetallePageState();
}

class _ProductoDetallePageState extends State<ProductoDetallePage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final CarritoService _carritoService = CarritoService();
  
  int _cantidad = 1;
  bool _isLoading = false;

  String _formatearMoneda(dynamic monto) {
    try {
      final valor = double.parse(monto.toString());
      return 'Bs. ${valor.toStringAsFixed(2)}';
    } catch (e) {
      return 'Bs. 0.00';
    }
  }

  Future<void> _agregarAlCarrito() async {
    if (widget.carritoActivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No hay carrito activo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('No hay sesión activa');

      final detalleData = {
        'carrito': widget.carritoActivo!['id'],
        'producto': widget.producto['id'],
        'cantidad': _cantidad,
        'precio_unitario': widget.producto['precio_venta'],
      };

      final result = await _carritoService.agregarProducto(token, detalleData);

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_cantidad ${widget.producto['nombre']} agregado(s) al carrito'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Ver carrito',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/carrito');
                },
              ),
            ),
          );
          Navigator.pop(context, true); // Retornar true para indicar que se agregó
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.producto['stock'] ?? 0;
    final tieneStock = stock > 0;
    final precioTotal = _cantidad * (double.tryParse(widget.producto['precio_venta'].toString()) ?? 0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Detalle del Producto'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen del producto
            Hero(
              tag: 'producto_${widget.producto['id']}',
              child: Container(
                height: 300,
                color: Colors.grey[200],
                child: widget.producto['imagen'] != null && widget.producto['imagen'] != ''
                    ? Image.network(
                        widget.producto['imagen'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Imagen no disponible',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sin imagen',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            
            // Información del producto
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del producto
                  Text(
                    widget.producto['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Código
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Código: ${widget.producto['codigo'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Precio
                  Row(
                    children: [
                      const Text(
                        'Precio:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatearMoneda(widget.producto['precio_venta']),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Stock
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tieneStock ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tieneStock ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tieneStock ? Icons.check_circle : Icons.cancel,
                          color: tieneStock ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tieneStock ? 'Disponible' : 'Sin stock',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: tieneStock ? Colors.green[700] : Colors.red[700],
                                ),
                              ),
                              if (tieneStock)
                                Text(
                                  '$stock unidades disponibles',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Categoría
                  if (widget.producto['categoria'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.category,
                            size: 20,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Categoría: ${widget.producto['categoria_nombre'] ?? 'Sin categoría'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Descripción
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.producto['descripcion'] != null && 
                    widget.producto['descripcion'].toString().isNotEmpty
                        ? widget.producto['descripcion']
                        : 'Este producto no tiene una descripción detallada disponible.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 80), // Espacio para el botón flotante
                ],
              ),
            ),
          ],
        ),
      ),
      
      // Botón de agregar al carrito flotante
      bottomNavigationBar: tieneStock
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Selector de cantidad
                    Row(
                      children: [
                        const Text(
                          'Cantidad:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _cantidad > 1
                                    ? () => setState(() => _cantidad--)
                                    : null,
                                icon: const Icon(Icons.remove),
                                color: Colors.deepPurple,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '$_cantidad',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _cantidad < stock
                                    ? () => setState(() => _cantidad++)
                                    : null,
                                icon: const Icon(Icons.add),
                                color: Colors.deepPurple,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Total y botón agregar
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _formatearMoneda(precioTotal),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _agregarAlCarrito,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_shopping_cart),
                            label: Text(
                              _isLoading ? 'Agregando...' : 'Agregar al Carrito',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Text(
                      'Producto sin stock disponible',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
