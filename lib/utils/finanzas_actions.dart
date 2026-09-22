import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;

/// Obtiene el nombre real de un personal a partir de su ID
Future<String> getPersonalRealName(String? personalId) async {
  if (personalId == null || personalId.isEmpty) return 'Desconocido';
  try {
    final res = await Supabase.instance.client
        .from('Personal')
        .select('nombre')
        .eq('userID', personalId)
        .maybeSingle();
    if (res != null) {
      return res['nombre']?.toString() ?? 'Sin nombre';
    }
  } catch (_) {}
  return 'Desconocido';
}

/// Elimina un registro de finanzas (Servicio o Producto) con confirmación previa
Future<void> confirmDeleteRecord({
  required BuildContext context,
  required Map<String, dynamic> record,
  required bool isService,
  required VoidCallback onRefreshed,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 10),
          Text('Eliminar Registro'),
        ],
      ),
      content: const Text(
        '¿Estás seguro de que deseas eliminar este registro permanentemente? Esta acción no se puede deshacer.',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  // Show loading indicator
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(color: Colors.black),
    ),
  );

  try {
    final client = Supabase.instance.client;
    final String recordId = record['id'].toString();

    if (isService) {
      await client.from('FinanzasPersonal').delete().eq('id', recordId);
    } else {
      // Si es venta de productos, restauramos el stock primero
      final products = record['productos_detalle'] as List? ?? [];
      for (var prod in products) {
        final prodId = prod['id'];
        final qty = int.tryParse(prod['cantidad']?.toString() ?? '0') ?? 0;
        if (prodId != null && qty > 0) {
          try {
            final prodResp = await client
                .from('Productos')
                .select('stock')
                .eq('id', prodId)
                .single();
            final currentStock = int.tryParse(prodResp['stock']?.toString() ?? '0') ?? 0;
            await client
                .from('Productos')
                .update({'stock': currentStock + qty})
                .eq('id', prodId);
          } catch (e) {
            debugPrint('Error restoring stock for product $prodId: $e');
          }
        }
      }
      await client.from('OrdenesProductos').delete().eq('id', recordId);
    }

    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro eliminado correctamente')),
      );
      onRefreshed();
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar registro: $e')),
      );
    }
  }
}

/// Muestra el diálogo para editar un registro
void showEditRecordDialog({
  required BuildContext context,
  required Map<String, dynamic> record,
  required bool isService,
  required VoidCallback onRefreshed,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _EditFinanceRecordDialog(
      record: record,
      isService: isService,
      onRefreshed: onRefreshed,
    ),
  );
}

class _EditFinanceRecordDialog extends StatefulWidget {
  final Map<String, dynamic> record;
  final bool isService;
  final VoidCallback onRefreshed;

  const _EditFinanceRecordDialog({
    required this.record,
    required this.isService,
    required this.onRefreshed,
  });

  @override
  State<_EditFinanceRecordDialog> createState() => _EditFinanceRecordDialogState();
}

class _EditFinanceRecordDialogState extends State<_EditFinanceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _client = Supabase.instance.client;

  late TextEditingController _sucursalCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _extrasCtrl;
  late TextEditingController _descCtrl;

  late String _selectedFormaPago;
  late DateTime _selectedDateTime;
  bool _isGasto = false;

  String _staffName = 'Cargando...';
  bool _loadingStaff = true;
  bool _saving = false;

  final List<String> _paymentMethods = [
    'En efectivo',
    'Tarjeta',
    'Transferencia',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    final rec = widget.record;
    _sucursalCtrl = TextEditingController(text: rec['sucursal']?.toString() ?? '');

    _selectedDateTime = rec['fecha'] != null
        ? DateTime.parse(rec['fecha'].toString()).toLocal()
        : DateTime.now();

    final rawFormaPago = rec['formadepago']?.toString() ?? 'En efectivo';
    // Normalize selected payment method
    _selectedFormaPago = _paymentMethods.firstWhere(
      (m) => m.toLowerCase().trim() == rawFormaPago.toLowerCase().trim(),
      orElse: () => _paymentMethods.contains(rawFormaPago) ? rawFormaPago : 'Otro',
    );

    if (widget.isService) {
      _isGasto = rec['Gasto'] != null && rec['Gasto'].toString().trim().isNotEmpty;
      if (_isGasto) {
        _amountCtrl = TextEditingController(text: rec['Gasto']?.toString() ?? '0.00');
        _extrasCtrl = TextEditingController(text: '0.00');
        _descCtrl = TextEditingController(text: rec['descripcion_extras']?.toString() ?? '');
      } else {
        _amountCtrl = TextEditingController(text: rec['suma_servicios']?.toString() ?? '0.00');
        _extrasCtrl = TextEditingController(text: rec['montos_extras']?.toString() ?? '0.00');
        _descCtrl = TextEditingController(text: rec['descripcion_extras']?.toString() ?? '');
      }
    } else {
      _amountCtrl = TextEditingController(text: rec['suma_productos']?.toString() ?? '0.00');
      _extrasCtrl = TextEditingController(text: '0.00');
      _descCtrl = TextEditingController();
    }

    _loadStaffName();
  }

  @override
  void dispose() {
    _sucursalCtrl.dispose();
    _amountCtrl.dispose();
    _extrasCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaffName() async {
    final rec = widget.record;
    final staffId = widget.isService ? rec['personalID'] : rec['personal_id'];
    final name = await getPersonalRealName(staffId?.toString());
    if (mounted) {
      setState(() {
        _staffName = name;
        _loadingStaff = false;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              dialHandColor: Colors.black,
              dialBackgroundColor: Color(0xFFF2F2F7),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final String recordId = widget.record['id'].toString();
      final double mainAmount = double.tryParse(_amountCtrl.text) ?? 0.0;
      final double extrasAmount = double.tryParse(_extrasCtrl.text) ?? 0.0;

      if (widget.isService) {
        if (_isGasto) {
          await _client.from('FinanzasPersonal').update({
            'Gasto': mainAmount.toStringAsFixed(2),
            'descripcion_extras': _descCtrl.text.trim(),
            'formadepago': _selectedFormaPago,
            'sucursal': _sucursalCtrl.text.trim(),
            'fecha': _selectedDateTime.toUtc().toIso8601String(),
            'total': mainAmount, // Total del gasto es el monto del gasto
          }).eq('id', recordId);
        } else {
          final total = mainAmount + extrasAmount;
          await _client.from('FinanzasPersonal').update({
            'suma_servicios': mainAmount,
            'montos_extras': extrasAmount,
            'descripcion_extras': _descCtrl.text.trim(),
            'formadepago': _selectedFormaPago,
            'sucursal': _sucursalCtrl.text.trim(),
            'fecha': _selectedDateTime.toUtc().toIso8601String(),
            'total': total,
          }).eq('id', recordId);
        }
      } else {
        await _client.from('OrdenesProductos').update({
          'suma_productos': mainAmount,
          'formadepago': _selectedFormaPago,
          'sucursal': _sucursalCtrl.text.trim(),
          'fecha': _selectedDateTime.toUtc().toIso8601String(),
        }).eq('id', recordId);
      }

      if (mounted) {
        widget.onRefreshed();
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro actualizado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar cambios: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.isService
        ? (_isGasto ? 'Editar Gasto' : 'Editar Servicio')
        : 'Editar Venta';

    return AlertDialog(
      title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Personal (Read-only)
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Registrado por (No editable)',
                    labelStyle: TextStyle(color: Colors.black54),
                    disabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black12),
                    ),
                  ),
                  initialValue: _loadingStaff ? 'Cargando...' : _staffName,
                  enabled: false,
                  style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),

                // Sucursal
                TextFormField(
                  controller: _sucursalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal',
                    labelStyle: TextStyle(color: Colors.black87),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'La sucursal es requerida' : null,
                ),
                const SizedBox(height: 12),

                // Fecha y Hora
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.black87),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fecha y Hora',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              intl.DateFormat('dd/MM/yyyy · HH:mm').format(_selectedDateTime),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 12),

                // Monto principal
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: widget.isService
                        ? (_isGasto ? 'Monto del Gasto' : 'Suma de Servicios')
                        : 'Suma de Productos',
                    labelStyle: const TextStyle(color: Colors.black87),
                    prefixText: '\$ ',
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'El monto es requerido';
                    if (double.tryParse(v) == null) return 'Monto inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Extras (Only for non-gasto services)
                if (widget.isService && !_isGasto) ...[
                  TextFormField(
                    controller: _extrasCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Montos Extras',
                      labelStyle: TextStyle(color: Colors.black87),
                      prefixText: '\$ ',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'El monto es requerido';
                      if (double.tryParse(v) == null) return 'Monto inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Descripción (Only for services/gastos)
                if (widget.isService) ...[
                  TextFormField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: _isGasto ? 'Descripción del Gasto' : 'Descripción Extras',
                      labelStyle: const TextStyle(color: Colors.black87),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Forma de Pago
                DropdownButtonFormField<String>(
                  initialValue: _selectedFormaPago,
                  decoration: const InputDecoration(
                    labelText: 'Forma de Pago',
                    labelStyle: TextStyle(color: Colors.black87),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  items: _paymentMethods.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(m),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedFormaPago = val;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
