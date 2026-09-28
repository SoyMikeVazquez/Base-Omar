// ============================================================================
// REGLA PRINCIPAL - PROYECTO OMAR:
// QUEDA ESTRICTAMENTE PROHIBIDO MODIFICAR ESTA PANTALLA (FinanzasFilteredRecordsScreen)
// Y SU LÓGICA DE FILTRADO/CÁLCULOS. CUALQUIER CAMBIO PUEDE AFECTAR LOS TOTALES Y KPI'S.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:totalpro/utils/formatters.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/finanzas_actions.dart';

// ─────────────────────────────────────────────
//  FinanzasFilteredRecordsScreen
// ─────────────────────────────────────────────

enum FinanzasFilterType { personal, sucursal }

class FinanzasFilteredRecordsScreen extends StatefulWidget {
  final FinanzasFilterType filterType;
  final String filterId;    // personalID o nombre de sucursal
  final String filterLabel; // nombre para mostrar
  final DateTime start;
  final DateTime end;
  final int cajaIndex;      // 0 = Recepción, 1 = Personal
  final String cajaLabel;

  const FinanzasFilteredRecordsScreen({
    super.key,
    required this.filterType,
    required this.filterId,
    required this.filterLabel,
    required this.start,
    required this.end,
    required this.cajaIndex,
    required this.cajaLabel,
  });

  @override
  State<FinanzasFilteredRecordsScreen> createState() =>
      _FinanzasFilteredRecordsScreenState();
}

class _FinanzasFilteredRecordsScreenState
    extends State<FinanzasFilteredRecordsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _servicios = [];
  List<Map<String, dynamic>> _productos = [];


  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final startStr = widget.start.toIso8601String();
      final endStr = widget.end.toIso8601String();
      final quienFilter = widget.cajaIndex == 0 ? 'recepcion' : 'Personal';

      var finQuery = _supabase
          .from('FinanzasPersonal')
          .select()
          .ilike('QuienRegistro', quienFilter)
          .gte('fecha', startStr)
          .lte('fecha', endStr);

      var ordQuery = _supabase
          .from('OrdenesProductos')
          .select()
          .gte('fecha', startStr)
          .lte('fecha', endStr);

      if (widget.filterType == FinanzasFilterType.personal) {
        finQuery = finQuery.eq('personalID', widget.filterId);
        ordQuery = ordQuery.eq('personal_id', widget.filterId);
      } else {
        finQuery = finQuery.eq('sucursal', widget.filterId);
        ordQuery = ordQuery.eq('sucursal', widget.filterId);
      }

      final results = await Future.wait([
        finQuery.order('fecha', ascending: false),
        ordQuery.order('fecha', ascending: false),
      ]);

      final finResp = List<Map<String, dynamic>>.from(results[0]);
      final ordResp = List<Map<String, dynamic>>.from(results[1]);

      double sumIncome = 0.0;
      double sumExpenses = 0.0;
      for (var r in finResp) {
        final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
        final gastoMonto = double.tryParse(r['Gasto']?.toString().replaceAll('\$', '').replaceAll('-', '').replaceAll(',', '.').trim() ?? '') ??
            double.tryParse((r['total'] ?? 0).toString().replaceAll(',', '.')) ??
            double.tryParse((r['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ??
            0.0;
        if (isGasto) {
          sumExpenses += gastoMonto;
        } else {
          sumIncome += double.tryParse((r['total'] ?? 0).toString().replaceAll(',', '.')) ?? 0.0;
        }
      }
      for (var r in ordResp) {
        sumIncome += double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
      }

      setState(() {
        _servicios = finResp;
        _productos = ordResp;
        _totalIncome = sumIncome;
        _totalExpenses = sumExpenses;
      });
    } catch (e) {
      debugPrint('Error fetching filtered records: $e');
      setState(() { _servicios = []; _productos = []; });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _currentRecords {
    final all = [..._servicios, ..._productos];
    all.sort((a, b) {
      final fa = a['fecha'] != null ? DateTime.parse(a['fecha']) : DateTime.fromMillisecondsSinceEpoch(0);
      final fb = b['fecha'] != null ? DateTime.parse(b['fecha']) : DateTime.fromMillisecondsSinceEpoch(0);
      return fb.compareTo(fa);
    });
    return all;
  }

  IconData _paymentIcon(String forma) {
    switch (forma.toLowerCase()) {
      case 'tarjeta': return Icons.credit_card_rounded;
      case 'transferencia': return Icons.swap_horiz_rounded;
      default: return Icons.payments_rounded;
    }
  }

  Widget _detailRow(String label, String value, {bool isLabel = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        isLabel
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              )
            : Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showDetails(Map<String, dynamic> rec) {
    final fecha = rec['fecha'] != null ? DateTime.parse(rec['fecha']) : null;
    final formaPago = rec['formadepago'] as String? ?? '';
    final sucursal = rec['sucursal'] ?? '';
    final isService = !rec.containsKey('suma_productos');
    final isGasto = isService && ((rec['Gasto'] != null && rec['Gasto'].toString().trim().isNotEmpty) || (rec['descripcion_extras'] == 'Gasto registrado'));
    final total = isGasto
        ? (double.tryParse(rec['Gasto']?.toString().replaceAll('\$', '').replaceAll('-', '').replaceAll(',', '.').trim() ?? '') ??
           double.tryParse((rec['total'] ?? 0).toString().replaceAll(',', '.')) ??
           double.tryParse((rec['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ??
           0.0)
        : (isService
            ? (double.tryParse((rec['total'] ?? 0).toString().replaceAll(',', '.')) ?? 0.0)
            : (double.tryParse((rec['suma_productos'] ?? 0).toString().replaceAll(',', '.')) ?? 0.0));
    final servicios = isService ? (rec['servicios_detalle'] as List? ?? []) : [];
    final productos = !isService ? (rec['productos_detalle'] as List? ?? []) : [];
    final extras = isService ? (double.tryParse((rec['montos_extras'] ?? 0).toString()) ?? 0.0) : 0.0;
    final serviciosSum = isService ? (double.tryParse((rec['suma_servicios'] ?? 0).toString()) ?? 0.0) : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 12, left: 24, right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isGasto ? Colors.red : Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isGasto ? Icons.arrow_outward_rounded : _paymentIcon(formaPago),
                        color: Colors.white, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fecha != null
                                ? intl.DateFormat('EEEE d \'de\' MMMM · HH:mm').format(fecha)
                                : 'Sin fecha',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(sucursal, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Text(
                      isGasto ? '-\$${formatMoney(total)}' : '\$${formatMoney(total)}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isGasto ? Colors.red : Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                if (isGasto) ...[
                  _detailRow('Monto del gasto', '\$${formatMoney(total)}'),
                ] else if (isService) ...[
                  _detailRow('Servicios', '\$${formatMoney(serviciosSum)}'),
                  const SizedBox(height: 8),
                  _detailRow('Montos extras', '\$${formatMoney(extras)}'),
                ] else ...[
                  _detailRow('Venta de productos', '\$${formatMoney(total)}'),
                ],
                const SizedBox(height: 8),
                _detailRow('Forma de pago', formaPago, isLabel: true),
                if (rec['QuienRegistro'] != null) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<String>(
                    future: getPersonalRealName(isService ? rec['personalID'] : rec['personal_id']),
                    builder: (context, snapshot) {
                      final staffName = snapshot.data;
                      final name = (staffName != null &&
                              staffName.isNotEmpty &&
                              staffName != 'Desconocido' &&
                              staffName != 'Cargando...')
                          ? staffName
                          : ((rec['QuienRegistro']?.toString().toLowerCase() == 'recepcion')
                              ? 'Recepción'
                              : (snapshot.data ?? 'Cargando...'));
                      return _detailRow('Registrado por', name);
                    },
                  ),
                ],
                if (isService && !isGasto && rec['descripcion_extras'] != null &&
                    (rec['descripcion_extras'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _detailRow('Descripción extras', rec['descripcion_extras']),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                if (isGasto) ...[
                  const Text('Detalle del gasto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(rec['descripcion_extras'] as String? ?? 'Gasto registrado', style: const TextStyle(fontSize: 14))),
                      Text('\$${formatMoney(total)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                    ],
                  ),
                ] else if (isService && servicios.isNotEmpty) ...[
                  const Text('Servicios realizados', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(height: 10),
                  ...servicios.map((s) {
                    final name = s['name'] ?? s['nombre'] ?? 'Servicio';
                    final price = s['price'] ?? s['precio'] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
                          Text('\$$price', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                ] else if (!isService && productos.isNotEmpty) ...[
                  const Text('Productos vendidos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(height: 10),
                  ...productos.map((p) {
                    final name = p['nombre'] ?? p['NombreProducto'] ?? p['name'] ?? 'Producto';
                    final price = p['precio'] ?? p['montoProducto'] ?? p['price'] ?? 0;
                    final qty = p['cantidad'] ?? 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(child: Text('$name  ×$qty', style: const TextStyle(fontSize: 14))),
                          Text('\$$price', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx); // Close sheet
                          showEditRecordDialog(
                            context: context,
                            record: rec,
                            isService: isService,
                            onRefreshed: _fetchRecords,
                          );
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.black87),
                        label: const Text('Editar', style: TextStyle(color: Colors.black87)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black26),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx); // Close sheet
                          confirmDeleteRecord(
                            context: context,
                            record: rec,
                            isService: isService,
                            onRefreshed: _fetchRecords,
                          );
                        },
                        icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.white),
                        label: const Text('Eliminar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(Map<String, dynamic> r) {
    final isService = !r.containsKey('suma_productos');
    final fecha = r['fecha'] != null ? DateTime.parse(r['fecha']) : null;
    final isGasto = isService && ((r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado'));
    final total = isGasto
        ? (double.tryParse(r['Gasto']?.toString().replaceAll('\$', '').replaceAll('-', '').replaceAll(',', '.').trim() ?? '') ??
           double.tryParse((r['total'] ?? 0).toString().replaceAll(',', '.')) ??
           double.tryParse((r['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ??
           0.0)
        : (isService
            ? (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0)
            : (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0));
    final formaPago = r['formadepago'] as String? ?? '';
    final sucursal = r['sucursal'] as String? ?? '';
    final itemsCount = isService
        ? (r['servicios_detalle'] as List? ?? []).length
        : (r['productos_detalle'] as List? ?? []).length;
    final itemLabel = isGasto
        ? 'Gasto'
        : (isService
            ? '$itemsCount servicio${itemsCount != 1 ? 's' : ''}'
            : '$itemsCount producto${itemsCount != 1 ? 's' : ''}');

    return GestureDetector(
      onTap: () => _showDetails(r),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: isGasto ? const Color(0xFFFBF2F2) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGasto ? Icons.arrow_outward_rounded : (isService ? _paymentIcon(formaPago) : Icons.shopping_bag_outlined),
                size: 20, color: isGasto ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fecha != null ? intl.DateFormat('dd/MM · HH:mm').format(fecha) : 'Sin fecha',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Builder(
                    builder: (context) {
                      final pid = (isService ? r['personalID'] : r['personal_id'])?.toString() ?? '';
                      return FutureBuilder<String>(
                        future: getPersonalRealName(pid),
                        builder: (context, snapshot) {
                          final staffName = snapshot.data;
                          final name = (staffName != null &&
                                  staffName.isNotEmpty &&
                                  staffName != 'Desconocido' &&
                                  staffName != 'Cargando...')
                              ? staffName
                              : ((r['QuienRegistro']?.toString().toLowerCase() == 'recepcion')
                                  ? 'Recepción'
                                  : sucursal);
                          final label = name.isNotEmpty ? '$name · $itemLabel' : itemLabel;
                          return Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isGasto ? Colors.red.withValues(alpha: 0.7) : Colors.black45,
                              fontWeight: isGasto ? FontWeight.w500 : FontWeight.normal,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isGasto ? '-\$${formatMoney(total)}' : '\$${formatMoney(total)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isGasto ? Colors.red : Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(formaPago, style: const TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _currentRecords;
    final isPersonal = widget.filterType == FinanzasFilterType.personal;
    final filterIcon = isPersonal ? Icons.person_rounded : Icons.store_rounded;
    final periodLabel =
        '${intl.DateFormat('d/MM').format(widget.start)} – ${intl.DateFormat('d/MM/yy').format(widget.end)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2E)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(filterIcon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.filterLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.cajaLabel}  ·  $periodLabel',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ingresos: \$${formatMoney(_totalIncome)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('Gastos: \$${formatMoney(_totalExpenses)}', style: TextStyle(color: Colors.red.shade300, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('Balance: ', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                    Text(
                                      '\$${formatMoney(_totalIncome - _totalExpenses)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registros',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text('${records.length} total',
                      style: const TextStyle(fontSize: 13, color: Colors.black38)),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 10)),

          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (records.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.bar_chart_rounded, color: Colors.black26, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text('Sin registros', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54)),
                      const SizedBox(height: 6),
                      const Text('No hay registros para este filtro', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.black38)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  if (i == records.length) return const SizedBox(height: 32);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _buildCard(records[i]),
                  );
                },
                childCount: records.length + 1,
              ),
            ),
        ],
      ),
    );
  }
}

