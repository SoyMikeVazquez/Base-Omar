import 'package:flutter/material.dart';
import 'package:totalpro/utils/formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/finanzas_service.dart';
import '../services/email_service.dart';
import '../services/whatsapp_service.dart';

class FinanzasRecepcionScreen extends StatefulWidget {
  final String personalId;
  const FinanzasRecepcionScreen({super.key, required this.personalId});

  @override
  State<FinanzasRecepcionScreen> createState() => _FinanzasRecepcionScreenState();
}

class _FinanzasRecepcionScreenState extends State<FinanzasRecepcionScreen> {
  final _supabase = Supabase.instance.client;
  final FinanzasService _service = FinanzasService();

  List<Map<String, dynamic>> _productos = [];
  final Map<String, int> _selectedProductos = {};
  final Map<String, double> _productoPrices = {};
  final Map<String, double> _customPrices = {};
  final Map<String, double> _customCommissions = {};

  List<Map<String, dynamic>> _services = [];
  final List<String> _selectedServiceIds = [];
  final Map<String, double> _servicePrices = {};
  List<String> _branches = [];
  String? _selectedSucursal;

  List<Map<String, dynamic>> _personalList = [];
  String? _selectedPersonalId;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final TextEditingController _montosExtrasController = TextEditingController();
  final TextEditingController _descripcionExtrasController =
      TextEditingController();
  final TextEditingController _gastoController = TextEditingController();
  final _clienteNombreCtrl = TextEditingController();
  final _clienteCorreoCtrl = TextEditingController();
  final _clienteTelefonoCtrl = TextEditingController();
  String _formaPago = 'En efectivo';
  String? _clienteId;
  bool _buscandoCliente = false;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showServices = true;
  bool _showProducts = false;
  bool _isExpense = false;
  bool _showMontosExtrasToggle = false;
  final Map<String, TextEditingController> _customServicePriceControllers = {};

  Future<void> _showEditPriceDialog(String productId, String productName, double currentPrice) async {
    final TextEditingController priceCtrl = TextEditingController(text: currentPrice.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Editar precio', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(productName, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio personalizado',
                  prefixText: '\$ ',
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () {
                final newPrice = double.tryParse(priceCtrl.text) ?? currentPrice;
                Navigator.pop(ctx, newPrice);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _customPrices[productId] = result;
      });
    }
  }
  @override

  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _montosExtrasController.dispose();
    _descripcionExtrasController.dispose();
    _gastoController.dispose();
    _clienteNombreCtrl.dispose();
    _clienteCorreoCtrl.dispose();
    _clienteTelefonoCtrl.dispose();
    for (var controller in _customServicePriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initData() async {
    await Future.wait([_fetchServices(), _fetchBranchesAndPersonal(), _fetchProductos()]);
  }

  Future<void> _fetchProductos() async {
    try {
      final prods = await _service.fetchProductos();
      if (mounted) {
        setState(() {
          _productos = prods;
          for (var p in _productos) {
            final precioVal = p['precio'] ?? p['montoProducto'] ?? '0';
            _productoPrices[p['id'].toString()] =
                double.tryParse(precioVal.toString()) ?? 0.0;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBranchesAndPersonal() async {
    try {
      final branchesResp = await _supabase
          .from('Sucursales')
          .select('NombreSucursal')
          .eq('IDGeneral', 'FRFROIJNU821')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal Canarios')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal florida')
          .order('NombreSucursal');
      final branchNames = (branchesResp as List)
          .map((b) => b['NombreSucursal'] as String)
          .toList();

      final staffResp = await _supabase
          .from('Personal')
          .select('userID, nombre, TipoPersonal')
          .order('nombre');
      final staffList = List<Map<String, dynamic>>.from(staffResp).where((p) {
        final tipo = p['TipoPersonal']?.toString().toLowerCase();
        return tipo == null || tipo == 'barbero' || tipo == 'estilista';
      }).toList();

      final personalResp = await _supabase
          .from('Personal')
          .select('sucursal')
          .eq('userID', widget.personalId)
          .maybeSingle();
      final defaultSucursal =
          personalResp != null ? personalResp['sucursal'] as String? : null;

      setState(() {
        _branches = branchNames.cast<String>().toList();
        _selectedSucursal =
            defaultSucursal ?? (_branches.isNotEmpty ? _branches.first : null);
        _personalList = staffList;
        if (_personalList.isNotEmpty) {
          _selectedPersonalId = _personalList.first['userID'] as String?;
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchServices() async {
    try {
      final resp = await _supabase
          .from('Services')
          .select('id, nameService, Price')
          .order('nameService');
      setState(() {
        _services = List<Map<String, dynamic>>.from(resp);
        for (var s in _services) {
          _servicePrices[s['id'].toString()] =
              double.tryParse((s['Price'] ?? '0').toString()) ?? 0.0;
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  double get _sumaServicios {
    double sum = 0;
    for (var id in _selectedServiceIds) {
      if (_customServicePriceControllers.containsKey(id)) {
        sum += double.tryParse(_customServicePriceControllers[id]!.text) ?? 0.0;
      } else {
        sum += _servicePrices[id] ?? 0.0;
      }
    }
    return sum;
  }

  double get _sumaProductos {
    double sum = 0;
    _selectedProductos.forEach((id, qty) {
      sum += (_customPrices[id] ?? _productoPrices[id] ?? 0.0) * qty;
    });
    return sum;
  }


  double get _montosExtras =>
      double.tryParse(
        _montosExtrasController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
      ) ??
      0.0;

  double get _gastoMonto =>
      double.tryParse(
        _gastoController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
      ) ??
      0.0;

  double get _total {
    if (_isExpense) {
      return _gastoMonto;
    }
    double total = 0.0;
    if (_showServices) {
      total += _sumaServicios + _montosExtras;
    }
    if (_showProducts) {
      total += _sumaProductos;
    }
    return total;
  }

  Future<void> _submit() async {
    if (_selectedPersonalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona al miembro del personal'),
        ),
      );
      return;
    }

    if (_isExpense) {
      if (_gastoController.text.trim().isEmpty || _gastoMonto <= 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingresa un monto válido de gasto'),
          ),
        );
        return;
      }
    } else {
      if (!_showServices && !_showProducts) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa al menos una sección (Servicios o Productos)'),
          ),
        );
        return;
      }

      if (_showServices && _selectedServiceIds.isEmpty && _montosExtras == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona al menos un servicio o agrega un monto extra'),
          ),
        );
        return;
      }

      if (_showProducts && _selectedProductos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona al menos un producto para la orden'),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      const quienRegistro = 'recepcion';

      if (_isExpense) {
        await _service.insertarRegistro(
          personalId: _selectedPersonalId!,
          serviciosIds: [],
          serviciosDetalle: [],
          sumaServicios: 0.0,
          montosExtras: _gastoMonto,
          descripcionExtras: 'Gasto registrado',
          formaPago: _formaPago,
          fecha: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _selectedTime.hour,
            _selectedTime.minute,
          ),
          sucursal: _selectedSucursal,
          gasto: _gastoController.text.trim(),
          quienRegistro: quienRegistro,
        );
      } else {
        // Calcular comisión por venta de productos de forma dinámica
        double comisionTotalProductos = 0.0;
        if (_showProducts) {
          for (var entry in _selectedProductos.entries) {
            final prod = _productos.firstWhere((p) => p['id'].toString() == entry.key);
            final double price = _customPrices[entry.key] ?? _productoPrices[entry.key] ?? 0.0;
            final double pvp = double.tryParse(prod['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
            final defaultComm = price * (pvp / 100.0);
            final customComm = _customCommissions[entry.key] ?? defaultComm;
            comisionTotalProductos += customComm * entry.value;
          }
        }

        // 1. Guardar Registro de Servicios (o extras) si aplica
        if (_showServices || _montosExtras > 0) {
          final serviciosDetalle = _selectedServiceIds.map((id) {
            final s = _services.firstWhere((e) => e['id'].toString() == id);
            return {
              'id': id,
              'name': s['nameService'],
              'price': _servicePrices[id] ?? 0.0,
            };
          }).toList();

          await _service.insertarRegistro(
            personalId: _selectedPersonalId!,
            serviciosIds: _selectedServiceIds,
            serviciosDetalle: serviciosDetalle,
            sumaServicios: _sumaServicios,
            montosExtras: _montosExtras,
            descripcionExtras: _descripcionExtrasController.text.trim(),
            formaPago: _formaPago,
            fecha: DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              _selectedTime.hour,
              _selectedTime.minute,
            ),
            sucursal: _selectedSucursal,
            gasto: null,
            quienRegistro: quienRegistro,
            clienteId: _clienteId,
            clienteEmail: _clienteCorreoCtrl.text.trim().isEmpty ? null : _clienteCorreoCtrl.text.trim(),
            clienteTelefono: _clienteTelefonoCtrl.text.trim().isEmpty ? null : _clienteTelefonoCtrl.text.trim(),
            clienteNombre: _clienteNombreCtrl.text.trim().isEmpty ? null : _clienteNombreCtrl.text.trim(),
            tipoTransaccion: 'servicio', // o null, lo dejamos como servicio por defecto
          );
        }

        // 1.5 Guardar Registro de Comisión por Productos como registro INDEPENDIENTE
        // (Oculto temporalmente a petición: las comisiones de productos no se suman al personal automáticamente)

        // 2. Guardar Orden de Productos si aplica
        if (_showProducts) {
          final productosDetalle = _selectedProductos.entries.map((e) {
            final prod = _productos.firstWhere((p) => p['id'].toString() == e.key);
            final nombreProd = prod['nombre'] ?? prod['NombreProducto'] ?? 'Producto';
            return {
              'id': e.key,
              'nombre': nombreProd,
              'precio_unitario': _customPrices[e.key] ?? _productoPrices[e.key] ?? 0.0,
              'cantidad': e.value,
              'subtotal': (_customPrices[e.key] ?? _productoPrices[e.key] ?? 0.0) * e.value,
            };
          }).toList();

          await _service.insertarOrdenProductos(
            personalId: _selectedPersonalId!,
            productosDetalle: productosDetalle,
            sumaProductos: _sumaProductos,
            formaPago: _formaPago,
            fecha: DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              _selectedTime.hour,
              _selectedTime.minute,
            ),
            sucursal: _selectedSucursal,
            quienRegistro: quienRegistro,
            clienteId: _clienteId,
            clienteEmail: _clienteCorreoCtrl.text.trim().isEmpty ? null : _clienteCorreoCtrl.text.trim(),
            clienteTelefono: _clienteTelefonoCtrl.text.trim().isEmpty ? null : _clienteTelefonoCtrl.text.trim(),
            clienteNombre: _clienteNombreCtrl.text.trim().isEmpty ? null : _clienteNombreCtrl.text.trim(),
          );
        }
      }

      // Enviar Ticket por Correo y/o WhatsApp de forma asíncrona
      final email = _clienteCorreoCtrl.text.trim();
      final phone = _clienteTelefonoCtrl.text.trim();
      if (!_isExpense && (email.isNotEmpty || phone.isNotEmpty)) {
        final List<Map<String, dynamic>> items = [];
        if (_showServices) {
          for (var id in _selectedServiceIds) {
            final s = _services.firstWhere((e) => e['id'].toString() == id);
            items.add({
              'name': s['nameService'],
              'price': _servicePrices[id] ?? 0.0,
              'qty': 1,
            });
          }
          if (_montosExtras > 0.0) {
            items.add({
              'name': _descripcionExtrasController.text.trim().isNotEmpty
                  ? 'Extras: ${_descripcionExtrasController.text.trim()}'
                  : 'Monto Extra',
              'price': _montosExtras,
              'qty': 1,
            });
          }
        }
        if (_showProducts) {
          _selectedProductos.forEach((id, qty) {
            final prod = _productos.firstWhere((p) => p['id'].toString() == id);
            items.add({
              'name': prod['nombre'] ?? prod['NombreProducto'] ?? 'Producto',
              'price': _customPrices[id] ?? _productoPrices[id] ?? 0.0,
              'qty': qty,
            });
          });
        }
        if (items.isNotEmpty) {
          if (email.isNotEmpty) {
            EmailService.sendPurchaseTicketEmail(
              toEmail: email,
              clientName: _clienteNombreCtrl.text.trim(),
              total: _total,
              sucursal: _selectedSucursal ?? 'General',
              formaPago: _formaPago,
              items: items,
            ).catchError((err) {
              debugPrint('Error enviando ticket por correo: $err');
              return false;
            });
          }
          if (phone.isNotEmpty) {
            WhatsAppService.sendPurchaseTicketWhatsApp(
              clientPhone: phone,
              clientName: _clienteNombreCtrl.text.trim(),
              total: _total,
              sucursal: _selectedSucursal ?? 'General',
              formaPago: _formaPago,
              items: items,
            ).catchError((err) {
              debugPrint('Error enviando ticket por WhatsApp: $err');
              return false;
            });
          }
        }
      }

      if (mounted) {
        String msg = '✓ Registro guardado exitosamente';
        if (_isExpense) {
          msg = '✓ Gasto registrado exitosamente';
        } else if (_showServices && _showProducts) {
          msg = '✓ Registro y orden de productos guardados';
        } else if (_showProducts) {
          msg = '✓ Orden de productos guardada';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('ERROR SAVING RECORD: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el registro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _buscarCliente() async {
    final email = _clienteCorreoCtrl.text.trim();
    final phone = _clienteTelefonoCtrl.text.trim();

    if (email.isEmpty && phone.isEmpty) return;

    setState(() => _buscandoCliente = true);
    try {
      var query = _supabase.from('clientes').select('IDCliente, nombre, correo, telefono');
      
      List<dynamic> resp;
      if (email.isNotEmpty && phone.isNotEmpty) {
        resp = await query.or('correo.eq.$email,telefono.eq.$phone');
      } else if (email.isNotEmpty) {
        resp = await query.eq('correo', email);
      } else {
        resp = await query.eq('telefono', phone);
      }

      if (resp.isNotEmpty) {
        final client = resp.first;
        setState(() {
          _clienteId = client['IDCliente']?.toString();
          if (_clienteNombreCtrl.text.trim().isEmpty) {
            _clienteNombreCtrl.text = client['nombre'] ?? '';
          }
          if (_clienteCorreoCtrl.text.trim().isEmpty) {
            _clienteCorreoCtrl.text = client['correo'] ?? '';
          }
          if (_clienteTelefonoCtrl.text.trim().isEmpty) {
            _clienteTelefonoCtrl.text = client['telefono'] ?? '';
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente encontrado: ${client['nombre']}'),
              backgroundColor: Colors.black,
            ),
          );
        }
      } else {
        setState(() {
          _clienteId = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente no encontrado en la base de datos.'),
              backgroundColor: Colors.black,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error buscando cliente: $e');
    } finally {
      if (mounted) setState(() => _buscandoCliente = false);
    }
  }

  Widget _buildClienteSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.person_pin_rounded, color: Colors.black87, size: 20),
              SizedBox(width: 8),
              Text(
                'Asociar Cliente / Enviar Ticket',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _clienteTelefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Teléfono del Cliente (Opcional)',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clienteCorreoCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Correo electrónico del Cliente (Opcional)',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clienteNombreCtrl,
            decoration: InputDecoration(
              hintText: 'Nombre del Cliente (Opcional)',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _buscandoCliente ? null : _buscarCliente,
                  icon: _buscandoCliente
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black))
                      : const Icon(Icons.search_rounded, size: 16, color: Colors.black),
                  label: const Text('Buscar en Clientes', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          if (_clienteId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text(
                  'Asociado a cliente registrado',
                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Nuevo registro (Recepción)'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Flujo normal: Selección de forma de pago
                        if (!_isExpense) ...[
                          const _SectionLabel(
                            icon: Icons.payments_rounded,
                            label: 'Forma de pago',
                          ),
                          const SizedBox(height: 12),
                          _PaymentSelector(
                            value: _formaPago,
                            onChanged: (v) => setState(() => _formaPago = v),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Miembro del personal (Común) ──────────────────────────
                        if (_personalList.isNotEmpty) ...[
                          const _SectionLabel(
                            icon: Icons.person_rounded,
                            label: 'Personal que lleva el registro',
                          ),
                          const SizedBox(height: 12),
                          _StyledDropdown<String>(
                            value: _selectedPersonalId,
                            hint: 'Selecciona personal',
                            items: _personalList
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p['userID'] as String,
                                    child: Text(p['nombre'] ?? 'Sin nombre'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedPersonalId = v),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Sucursal (Común) ──────────────────────────
                        if (_branches.isNotEmpty) ...[
                          const _SectionLabel(
                            icon: Icons.store_rounded,
                            label: 'Sucursal',
                          ),
                          const SizedBox(height: 12),
                          _StyledDropdown<String>(
                            value: _selectedSucursal,
                            hint: 'Selecciona sucursal',
                            items: _branches
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedSucursal = v),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Fecha y hora (Común) ──────────────────────
                        _SectionLabel(
                          icon: Icons.calendar_today_rounded,
                          label: _isExpense ? 'Fecha y hora del gasto' : 'Fecha y hora del servicio',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _DateTimeButton(
                                icon: Icons.calendar_today_rounded,
                                label: 'Fecha',
                                value:
                                    '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                onTap: () async {
                                  final today = DateTime.now();
                                  final yesterday = DateTime(
                                    today.year,
                                    today.month,
                                    today.day,
                                  ).subtract(const Duration(days: 1));
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: yesterday,
                                    lastDate: today,
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DateTimeButton(
                                icon: Icons.access_time_rounded,
                                label: 'Hora',
                                value: _selectedTime.format(context),
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedTime = picked);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        // Si NO es un gasto, mostrar servicios y productos abajo de la fecha y hora
                        if (!_isExpense) ...[
                          const SizedBox(height: 24),
                          //_buildClienteSection(),
                          const SizedBox(height: 24),
                          
                          // ── Switch de Servicios ───────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Registrar servicios realizados',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Servicios de barbería realizados',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch.adaptive(
                                  value: _showServices,
                                  activeTrackColor: Colors.black,
                                  onChanged: (val) {
                                    setState(() {
                                      _showServices = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          if (_showServices) ...[
                            const SizedBox(height: 24),
                            // ── Servicios ──────────────────────────
                            const _SectionLabel(
                              icon: Icons.design_services_rounded,
                              label: 'Servicios realizados',
                            ),
                            const SizedBox(height: 12),
                            if (_services.isEmpty)
                              const _EmptyChipHint()
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _services.map((s) {
                                  final id = s['id'].toString();
                                  final name = s['nameService'] ?? '';
                                  final price = _servicePrices[id] ?? 0.0;
                                  final selected =
                                      _selectedServiceIds.contains(id);
                                  return _ServiceChip(
                                    name: name,
                                    price: price,
                                    selected: selected,
                                    onTap: () {
                                      setState(() {
                                        if (selected) {
                                          _selectedServiceIds.remove(id);
                                          _customServicePriceControllers.remove(id)?.dispose();
                                        } else {
                                          _selectedServiceIds.add(id);
                                          _customServicePriceControllers[id] = TextEditingController(text: price.toStringAsFixed(2));
                                          _customServicePriceControllers[id]!.addListener(() {
                                            setState(() {});
                                          });
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),

                            // Resumen y campos de servicios seleccionados
                            if (_selectedServiceIds.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ..._selectedServiceIds.map((id) {
                                final serviceName = _services.firstWhere((s) => s['id'].toString() == id, orElse: () => {'nameService': ''})['nameService'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: TextField(
                                    controller: _customServicePriceControllers[id],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Precio: $serviceName',
                                      prefixText: '\$ ',
                                      prefixStyle: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF2F2F7),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.black,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      "${_selectedServiceIds.length} servicio${_selectedServiceIds.length != 1 ? 's' : ''} seleccionado${_selectedServiceIds.length != 1 ? 's' : ''}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '\$${formatMoney(_sumaServicios)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            // ── Montos extras ─────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const _SectionLabel(
                                  icon: Icons.add_circle_outline_rounded,
                                  label: 'Montos extras',
                                ),
                                Switch(
                                  value: _showMontosExtrasToggle,
                                  activeColor: Colors.black,
                                  onChanged: (val) {
                                    setState(() {
                                      _showMontosExtrasToggle = val;
                                      if (!val) {
                                        _montosExtrasController.clear();
                                        _descripcionExtrasController.clear();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (_showMontosExtrasToggle) ...[
                              const SizedBox(height: 12),
                            TextField(
                              controller: _montosExtrasController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: '\$ ',
                                prefixStyle: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF2F2F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _descripcionExtrasController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Descripción (opcional)',
                                filled: true,
                                fillColor: const Color(0xFFF2F2F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],

                          const SizedBox(height: 24),

                          // ── Switch de Productos ────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subir una orden de productos',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Venta de productos en sucursal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch.adaptive(
                                  value: _showProducts,
                                  activeTrackColor: Colors.black,
                                  onChanged: (val) {
                                    setState(() {
                                      _showProducts = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          if (_showProducts) ...[
                            const SizedBox(height: 24),
                            // ── Productos ──────────────────────────
                            const _SectionLabel(
                              icon: Icons.inventory_2_outlined,
                              label: 'Productos vendidos (Orden de productos)',
                            ),
                            const SizedBox(height: 12),
                            if (_productos.isEmpty)
                              const _EmptyChipHint(label: 'No hay productos disponibles')
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Mostrar productos seleccionados como tarjetas con campos
                                  if (_selectedProductos.isNotEmpty) ...[
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _selectedProductos.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                      itemBuilder: (ctx, i) {
                                        final id = _selectedProductos.keys.elementAt(i);
                                        final qty = _selectedProductos.values.elementAt(i);
                                        final p = _productos.firstWhere((p) => p['id'].toString() == id);
                                        final name = p['nombre'] ?? p['NombreProducto'] ?? 'Producto';
                                        final stock = p['stock'] as int? ?? 0;
                                        
                                        final defaultPrice = _productoPrices[id] ?? 0.0;
                                        final price = _customPrices[id] ?? defaultPrice;
                                        
                                        final pvp = double.tryParse(p['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
                                        final defaultComm = price * (pvp / 100.0);
                                        final commission = _customCommissions[id] ?? defaultComm;

                                        return _SelectedProductCard(
                                          name: name,
                                          price: price,
                                          commission: commission,
                                          stock: stock,
                                          quantity: qty,
                                          onAdd: () {
                                            if (qty < stock) {
                                              setState(() => _selectedProductos[id] = qty + 1);
                                            }
                                          },
                                          onRemove: () {
                                            if (qty > 0) {
                                              setState(() {
                                                _selectedProductos[id] = qty - 1;
                                                if (_selectedProductos[id] == 0) {
                                                  _selectedProductos.remove(id);
                                                  _customPrices.remove(id);
                                                  _customCommissions.remove(id);
                                                }
                                              });
                                            }
                                          },
                                          onPriceChanged: (newPrice) {
                                            setState(() {
                                              _customPrices[id] = newPrice;
                                              // Recalcular comisión por defecto si cambian el precio y no la habían personalizado
                                              if (!_customCommissions.containsKey(id)) {
                                                _customCommissions[id] = newPrice * (pvp / 100.0);
                                              }
                                            });
                                          },
                                          onCommissionChanged: (newComm) {
                                            setState(() => _customCommissions[id] = newComm);
                                          }
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Agregar más productos:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 8),
                                  ],
                                  
                                  // Mostrar productos NO seleccionados como chips
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _productos.where((p) => !(_selectedProductos.containsKey(p['id'].toString()) && _selectedProductos[p['id'].toString()]! > 0)).map((p) {
                                      final id = p['id'].toString();
                                      final name = p['nombre'] ?? p['NombreProducto'] ?? 'Producto';
                                      final price = _productoPrices[id] ?? 0.0;
                                      
                                      return ActionChip(
                                        backgroundColor: const Color(0xFFF2F2F7),
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        label: Text('$name (\$${price.toInt()})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                        onPressed: () {
                                          if ((p['stock'] as int? ?? 0) > 0) {
                                            setState(() => _selectedProductos[id] = 1);
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),

                            // Resumen productos seleccionados
                            if (_selectedProductos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Builder(
                                builder: (ctx) {
                                  double comisionActual = 0.0;
                                  for (var entry in _selectedProductos.entries) {
                                    final prod = _productos.firstWhere((p) => p['id'].toString() == entry.key);
                                    final double pPrice = _customPrices[entry.key] ?? _productoPrices[entry.key] ?? 0.0;
                                    final double pvp = double.tryParse(prod['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
                                    final defaultComm = pPrice * (pvp / 100.0);
                                    final customComm = _customCommissions[entry.key] ?? defaultComm;
                                    comisionActual += customComm * entry.value;
                                  }
                                  if (false) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.monetization_on_rounded, color: Colors.green, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Comisión estimada para el personal: \$${comisionActual.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '${_selectedProductos.values.fold(0, (sum, qty) => sum + qty)} producto(s) en orden',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '\$${formatMoney(_sumaProductos)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],

                        // ── Switch de Gasto (Rojo) como última opción ───────────
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Registrar como Gasto',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.red,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Registrar salida de dinero',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _isExpense,
                                activeThumbColor: Colors.red,
                                activeTrackColor: Colors.red.withOpacity(0.5),
                                onChanged: (val) {
                                  setState(() {
                                    _isExpense = val;
                                    if (val) {
                                      _showServices = false;
                                      _showProducts = false;
                                    } else {
                                      _showServices = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // Si es un gasto, mostrar campos específicos del gasto debajo de él
                        if (_isExpense) ...[
                          const SizedBox(height: 20),
                          const _SectionLabel(
                            icon: Icons.monetization_on_outlined,
                            label: 'Monto del gasto',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _gastoController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              prefixText: '\$ ',
                              prefixStyle: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF2F2F7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 24),

                          const _SectionLabel(
                            icon: Icons.payments_rounded,
                            label: 'Método de pago del gasto',
                          ),
                          const SizedBox(height: 12),
                          _PaymentSelector(
                            value: _formaPago,
                            onChanged: (v) => setState(() => _formaPago = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Footer fijo con total y botón ─────────────
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    mq.padding.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Desglose
                      if (_isExpense && _gastoMonto > 0) ...[
                        Row(
                          children: [
                            const Text('Gasto', style: TextStyle(color: Colors.black38, fontSize: 13)),
                            const Spacer(),
                            Text('\$${formatMoney(_gastoMonto)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ] else ...[
                        if (_showServices && _sumaServicios > 0) ...[
                          Row(
                            children: [
                              const Text('Servicios', style: TextStyle(color: Colors.black38, fontSize: 13)),
                              const Spacer(),
                              Text('\$${formatMoney(_sumaServicios)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ],
                        if (_showProducts && _sumaProductos > 0) ...[
                          if (_showServices && _sumaServicios > 0) const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('Productos', style: TextStyle(color: Colors.black38, fontSize: 13)),
                              const Spacer(),
                              Text('\$${formatMoney(_sumaProductos)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ],
                        if (_showServices && _montosExtras > 0) ...[
                          if ((_showServices && _sumaServicios > 0) || (_showProducts && _sumaProductos > 0)) const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('Extras', style: TextStyle(color: Colors.black38, fontSize: 13)),
                              const Spacer(),
                              Text('\$${formatMoney(_montosExtras)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ],
                      ],
                      const SizedBox(height: 8),
                      // Total
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\$${formatMoney(_total)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Botón
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Guardar registro',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
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

// ─────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final String name;
  final double price;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceChip({
    required this.name,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 5),
            ],
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '\$${price % 1 == 0 ? price.toInt() : price}',
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white70 : Colors.black38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PaymentSelector({required this.value, required this.onChanged});

  static const _options = [
    ('En efectivo', Icons.payments_rounded),
    ('Tarjeta', Icons.credit_card_rounded),
    ('Transferencia', Icons.swap_horiz_rounded),
    ('Otro', Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final (label, icon) = opt;
        final selected = value == label;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(
                right: label != _options.last.$1 ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? Colors.black : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? Colors.white : Colors.black54,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label == 'En efectivo' ? 'Efectivo' : label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(color: Colors.black38, fontSize: 14),
          ),
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, color: Colors.black54),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: items,
          onChanged: onChanged,
          dropdownColor: Colors.white,
        ),
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.black54),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChipHint extends StatelessWidget {
  final String label;
  const _EmptyChipHint({this.label = 'No hay servicios disponibles'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Colors.black38),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.black38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  final String name;
  final double price;
  final int stock;
  final int quantity;
  final VoidCallback? onEditPrice;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductChip({
    required this.name,
    required this.price,
    required this.stock,
    required this.quantity,
    this.onEditPrice,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.black : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Colors.black : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${price % 1 == 0 ? price.toInt() : price} • Stock: $stock',
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white70 : Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              if (selected && onEditPrice != null) ...[
                GestureDetector(
                  onTap: onEditPrice,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white24 : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove, size: 14, color: selected ? Colors.white : Colors.black),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$quantity',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white24 : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, size: 14, color: selected ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedProductCard extends StatefulWidget {
  final String name;
  final double price;
  final double commission;
  final int stock;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<double> onCommissionChanged;

  const _SelectedProductCard({
    required this.name,
    required this.price,
    required this.commission,
    required this.stock,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    required this.onPriceChanged,
    required this.onCommissionChanged,
  });

  @override
  State<_SelectedProductCard> createState() => _SelectedProductCardState();
}

class _SelectedProductCardState extends State<_SelectedProductCard> {
  late TextEditingController _priceCtrl;
  late TextEditingController _commCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.price.toStringAsFixed(2));
    _commCtrl = TextEditingController(text: widget.commission.toStringAsFixed(2));
  }
  
  @override
  void didUpdateWidget(_SelectedProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.price != widget.price && double.tryParse(_priceCtrl.text) != widget.price) {
      _priceCtrl.text = widget.price.toStringAsFixed(2);
    }
    if (oldWidget.commission != widget.commission && double.tryParse(_commCtrl.text) != widget.commission) {
      _commCtrl.text = widget.commission.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _commCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.remove, size: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${widget.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Precio Unitario', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          final newVal = double.tryParse(val);
                          if (newVal != null) widget.onPriceChanged(newVal);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}
