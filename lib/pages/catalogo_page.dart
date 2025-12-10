import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/producto_service.dart';
import '../services/carrito_service.dart';
import '../services/auth_service.dart';
import '../services/categoria_service.dart';
import '../widgets/app_drawer.dart';
import 'producto_detalle_page.dart';

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key});

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ProductoService _productoService = ProductoService();
  final CarritoService _carritoService = CarritoService();
  final AuthService _authService = AuthService();
  final CategoriaService _categoriaService = CategoriaService();

  List<dynamic> _productos = [];
  List<dynamic> _categorias = [];
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _carritoActivo;
  bool _isLoading = true;
  String? _error;
  String? _token;
  int? _categoriaSeleccionada;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Speech to Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _currentLocale = 'es_ES';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadData();
    _initSpeech();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          print('🎤 Status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          print('❌ Error de voz: $error');
          setState(() => _isListening = false);
        },
      );
      
      if (_speechAvailable) {
        var locales = await _speech.locales();
        var spanishLocale = locales.firstWhere(
          (locale) => locale.localeId.startsWith('es'),
          orElse: () => locales.first,
        );
        _currentLocale = spanishLocale.localeId;
        print('🎤 Speech disponible en: $_currentLocale');
      }
      
      setState(() {});
    } catch (e) {
      print('❌ Error al inicializar speech: $e');
      _speechAvailable = false;
    }
  }

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se necesita permiso de micrófono para usar búsqueda por voz'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconocimiento de voz no disponible en este dispositivo'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _searchController.text = result.recognizedWords;
          _searchQuery = result.recognizedWords;
        });
      },
      localeId: _currentLocale,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
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

      // Cargar categorías
      final categoriasRes = await _categoriaService.getCategorias(_token!);
      if (categoriasRes['success']) {
        _categorias = categoriasRes['data'] ?? [];
      }

      // Cargar productos
      await _cargarProductos();

      // Obtener o crear carrito activo
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

  Future<void> _cargarProductos() async {
    try {
      final productosRes = await _productoService.getProductos(
        _token!,
        categoriaId: _categoriaSeleccionada,
      );
      
      if (!productosRes['success']) {
        throw Exception(productosRes['message']);
      }

      setState(() {
        _productos = productosRes['data'] ?? [];
      });
    } catch (e) {
      print('Error al cargar productos: $e');
    }
  }

  List<dynamic> get _productosFiltrados {
    if (_searchQuery.isEmpty) {
      return _productos;
    }

    return _productos.where((producto) {
      final nombre = (producto['nombre'] ?? '').toString().toLowerCase();
      final codigo = (producto['codigo'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return nombre.contains(query) || codigo.contains(query);
    }).toList();
  }

  Future<void> _filtrarPorCategoria(int? categoriaId) async {
    setState(() {
      _categoriaSeleccionada = categoriaId;
      _isLoading = true;
    });

    await _cargarProductos();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _obtenerCarritoActivo() async {
    try {
      print('Obteniendo carrito activo...');
      
      // Verificar que tenemos datos del usuario
      if (_userData == null || _userData!['id'] == null) {
        print('ERROR: No hay datos de usuario o ID de cliente');
        return;
      }
      
      final clienteId = _userData!['id'];
      print('Cliente ID: $clienteId');
      
      // Obtener todos los carritos
      final carritosRes = await _carritoService.getCarritos(_token!);
      
      if (!carritosRes['success']) {
        print('Error al obtener carritos: ${carritosRes['message']}');
        throw Exception(carritosRes['message']);
      }
      
      final carritos = carritosRes['data'] as List<dynamic>;
      print('Carritos obtenidos: ${carritos.length}');
      
      // Buscar carrito activo del cliente
      _carritoActivo = carritos.firstWhere(
        (c) => c['estado'] == 'activo' && c['cliente'] == clienteId,
        orElse: () => null,
      );

      if (_carritoActivo != null) {
        print('Carrito activo encontrado: ${_carritoActivo!['id']}');
      } else {
        print('No se encontró carrito activo, creando uno nuevo...');
        await _crearCarritoNuevo(clienteId);
      }
    } catch (e) {
      print('Error al obtener carrito activo: $e');
      rethrow;
    }
  }

  Future<void> _crearCarritoNuevo(int clienteId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final carritoData = {
        'codigo': 'CAR-$clienteId-$timestamp',
        'cliente': clienteId,
        'estado': 'activo',
      };

      print('Creando nuevo carrito para cliente $clienteId: $carritoData');
      final result = await _carritoService.crearCarrito(_token!, carritoData);
      
      if (result['success']) {
        print('Carrito creado exitosamente: ${result['data']}');
        setState(() {
          _carritoActivo = result['data'];
        });
      } else {
        print('Error al crear carrito: ${result['message']}');
        throw Exception(result['message']);
      }
    } catch (e) {
      print('Error al crear carrito: $e');
      rethrow;
    }
  }

  Future<void> _agregarAlCarrito(dynamic producto) async {
    try {
      // Verificar si hay carrito activo, si no, intentar obtenerlo o crearlo
      if (_carritoActivo == null) {
        print('No hay carrito activo, intentando obtener o crear uno...');
        await _obtenerCarritoActivo();
        
        // Si después de obtener/crear sigue siendo null, mostrar error
        if (_carritoActivo == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se pudo crear el carrito. Intenta nuevamente.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final detalleData = {
        'carrito': _carritoActivo!['id'],
        'producto': producto['id'],
        'cantidad': 1,
        'precio_unitario': producto['precio_venta'],
      };

      print('Agregando producto al carrito ${_carritoActivo!['id']}');
      final result = await _carritoService.agregarProducto(_token!, detalleData);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${producto['nombre']} agregado al carrito'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ver carrito',
              textColor: Colors.white,
              onPressed: () => Navigator.pushNamed(context, '/carrito'),
            ),
          ),
        );
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      print('Error al agregar al carrito: $e');
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

  void _mostrarDetalleProducto(dynamic producto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductoDetallePage(
          producto: producto,
          carritoActivo: _carritoActivo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Catálogo de Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.pushNamed(context, '/carrito'),
          ),
        ],
      ),
      drawer: AppDrawer(userData: _userData),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o código...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Botón de micrófono
                Container(
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red : Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                    onPressed: _isListening ? _stopListening : _startListening,
                    tooltip: _isListening ? 'Detener grabación' : 'Buscar por voz',
                  ),
                ),
              ],
            ),
          ),
          // Indicador de escucha
          if (_isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red[50],
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Escuchando... Di el nombre o código del producto',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          // Filtro de categorías
          if (_categorias.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Botón "Todos"
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Todos'),
                      selected: _categoriaSeleccionada == null,
                      onSelected: (selected) {
                        if (selected) _filtrarPorCategoria(null);
                      },
                      selectedColor: Colors.deepPurple,
                      labelStyle: TextStyle(
                        color: _categoriaSeleccionada == null ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Chips de categorías
                  ..._categorias.map((cat) {
                    final isSelected = _categoriaSeleccionada == cat['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat['nombre'] ?? ''),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) _filtrarPorCategoria(cat['id']);
                        },
                        selectedColor: Colors.deepPurple,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          // Lista de productos
          Expanded(
            child: _isLoading
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
              : _productos.isEmpty
                  ? const Center(
                      child: Text('No hay productos disponibles'),
                    )
                  : _productosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No se encontraron productos\ncon "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.68,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _productosFiltrados.length,
                            itemBuilder: (context, index) {
                              final producto = _productosFiltrados[index];
                              final stock = producto['stock'] ?? 0;
                              final tieneStock = stock > 0;

                              return GestureDetector(
                                onTap: () => _mostrarDetalleProducto(producto),
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Imagen del producto
                                      Expanded(
                                        flex: 4,
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(12),
                                          ),
                                          child: producto['imagen'] != null && producto['imagen'] != ''
                                              ? Image.network(
                                                  producto['imagen'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.image_not_supported,
                                                        size: 50,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.shopping_bag,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      // Información del producto y botón
                                      Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        producto['nombre'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatearMoneda(producto['precio_venta']),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.inventory_2,
                                            size: 11,
                                            color: tieneStock ? Colors.green : Colors.red,
                                          ),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              tieneStock ? 'Stock: $stock' : 'Sin stock',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: tieneStock ? Colors.grey[600] : Colors.red,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Botón agregar al carrito
                                      SizedBox(
                                        width: double.infinity,
                                        height: 32,
                                        child: ElevatedButton.icon(
                                          onPressed: tieneStock
                                              ? () => _agregarAlCarrito(producto)
                                              : null,
                                          icon: const Icon(Icons.add_shopping_cart, size: 14),
                                          label: const Text('Agregar', style: TextStyle(fontSize: 10)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.deepPurple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
          ),
        ],
      ),
    );
  }
}






