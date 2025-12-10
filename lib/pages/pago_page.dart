import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/pago_service.dart';

class PagoPage extends StatefulWidget {
  final Map<String, dynamic> carritoData;

  const PagoPage({super.key, required this.carritoData});

  @override
  State<PagoPage> createState() => _PagoPageState();
}

class _PagoPageState extends State<PagoPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final PagoService _pagoService = PagoService();
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de la tarjeta de prueba
  final TextEditingController _numeroTarjetaController = TextEditingController(text: '4242424242424242');
  final TextEditingController _mesController = TextEditingController(text: '12');
  final TextEditingController _anioController = TextEditingController(text: '25');
  final TextEditingController _cvvController = TextEditingController(text: '123');

  bool _procesando = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    _token = await _storage.read(key: 'access_token');
  }

  String _formatearMoneda(dynamic monto) {
    try {
      final valor = double.parse(monto.toString());
      return '\$${valor.toStringAsFixed(2)}';
    } catch (e) {
      return '\$0.00';
    }
  }

  Future<void> _procesarPago() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _procesando = true);

    try {
      // Simular procesamiento de pago (igual que React)
      print("💳 Procesando pago...");
      await Future.delayed(const Duration(seconds: 2));

      // Simulación de éxito del pago (90% de éxito como en web)
      if (DateTime.now().millisecond % 10 > 0) {
        print("💳 Pago procesado exitosamente");

        // 1. Crear la nota de venta desde el carrito
        print("📄 Creando nota de venta desde carrito: ${widget.carritoData['id']}");
        final notaVentaRes = await _pagoService.crearNotaDeVentaDesdeCarrito(
          _token!,
          widget.carritoData['id'],
        );

        if (!notaVentaRes['success']) {
          throw Exception(notaVentaRes['message']);
        }

        final notaVenta = notaVentaRes['data'];
        print("✅ Nota de venta creada: ${notaVenta['id']}");

        // 2. Crear el registro en el pago (simulado con payment_intent_id)
        final paymentIntentId = 'pi_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
        print("💳 Payment Intent ID: $paymentIntentId");

        final pagoData = {
          'nota_venta': notaVenta['id'],
          'monto': notaVenta['total'],
          'moneda': 'USD',
          'total_stripe': paymentIntentId,
        };

        print("💰 Creando registro de pago");
        final pagoRes = await _pagoService.crearPago(_token!, pagoData);

        if (!pagoRes['success']) {
          throw Exception(pagoRes['message']);
        }

        // 3. Marcar la nota de venta como pagada
        print("✅ Marcando nota de venta como pagada");
        final marcarRes = await _pagoService.marcarNotaDeVentaPagada(
          _token!,
          notaVenta['id'],
        );

        if (!marcarRes['success']) {
          throw Exception(marcarRes['message']);
        }

        // 4. Registrar en el historial de ventas
        print("📊 Registrando en historial de ventas");
        final historialRes = await _pagoService.crearHistorialDesdeNotaVenta(
          _token!,
          notaVenta['id'],
        );

        if (!historialRes['success']) {
          throw Exception(historialRes['message']);
        }

        print("✅ Registro histórico creado");

        // 5. Navegar a la página de éxito con la información completa
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/pago-exitoso',
            arguments: {
              'notaVenta': notaVenta,
              'monto': notaVenta['total'],
              'paymentIntentId': paymentIntentId,
              'orden': notaVenta['numero_comprobante'],
              'notaVentaId': notaVenta['id'],
              'fecha': DateTime.now().toIso8601String(),
            },
          );
        }
      } else {
        throw Exception("El pago fue rechazado. Por favor, intenta con otra tarjeta.");
      }
    } catch (e) {
      print("❌ Error al procesar pago: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar el pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  @override
  void dispose() {
    _numeroTarjetaController.dispose();
    _mesController.dispose();
    _anioController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Procesar Pago'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Resumen del pedido
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumen del Pedido',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Items:', style: TextStyle(fontSize: 16)),
                          Text(
                            '${widget.carritoData['total_items'] ?? 0}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            _formatearMoneda(widget.carritoData['total_carrito']),
                            style: const TextStyle(
                              fontSize: 22,
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
              const SizedBox(height: 24),

              // Información de prueba
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Modo de Prueba',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tarjeta de prueba precargada:\n• 4242 4242 4242 4242\n• Cualquier fecha futura\n• Cualquier CVV de 3 dígitos',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Formulario de tarjeta
              const Text(
                'Información de Pago',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Número de tarjeta
              TextFormField(
                controller: _numeroTarjetaController,
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: InputDecoration(
                  labelText: 'Número de Tarjeta',
                  hintText: '4242 4242 4242 4242',
                  prefixIcon: const Icon(Icons.credit_card),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el número de tarjeta';
                  }
                  if (value.replaceAll(' ', '').length < 16) {
                    return 'Número de tarjeta inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fecha de expiración y CVV
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mesController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: InputDecoration(
                        labelText: 'Mes',
                        hintText: 'MM',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        final mes = int.tryParse(value);
                        if (mes == null || mes < 1 || mes > 12) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _anioController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: InputDecoration(
                        labelText: 'Año',
                        hintText: 'AA',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        if (value.length < 3) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Botón de pagar
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _procesando ? null : _procesarPago,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _procesando
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Pagar ${_formatearMoneda(widget.carritoData['total_carrito'])}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
