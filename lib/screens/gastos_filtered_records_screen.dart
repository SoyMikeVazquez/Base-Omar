import 'package:flutter/material.dart';
import 'package:totalpro/utils/formatters.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/finanzas_actions.dart';

class GastosFilteredRecordsScreen extends StatefulWidget {
  final String sucursalId;
  final String sucursalLabel;
  final DateTime start;
  final DateTime end;
  final int cajaIndex;

  const GastosFilteredRecordsScreen({
    super.key,
    required this.sucursalId,
    required this.sucursalLabel,
    required this.start,
    required this.end,
    required this.cajaIndex,
  });

  @override
  State<GastosFilteredRecordsScreen> createState() => _GastosFilteredRecordsScreenState();
}

class _GastosFilteredRecordsScreenState extends State<GastosFilteredRecordsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _gastos = [];
  double _totalGastos = 0.0;

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

      final res = await _supabase
          .from('FinanzasPersonal')
          .select()
          .ilike('QuienRegistro', quienFilter)
          .gte('fecha', startStr)
          .lte('fecha', endStr)
          .eq('sucursal', widget.sucursalId)
          .neq('Gasto', '') // Only expenses
          .order('fecha', ascending: false);

      final gastosList = List<Map<String, dynamic>>.from(res);
      double sum = 0.0;
      
      final filteredGastos = <Map<String, dynamic>>[];
      for (var r in gastosList) {
        final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
        if (isGasto) {
          final gastoMonto = double.tryParse(r['Gasto']?.toString().replaceAll('\$', '').replaceAll('-', '').replaceAll(',', '.').trim() ?? '') ??
              double.tryParse((r['total'] ?? 0).toString().replaceAll(',', '.')) ??
              double.tryParse((r['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ??
              0.0;
          sum += gastoMonto;
          filteredGastos.add(r);
        }
      }

      setState(() {
        _gastos = filteredGastos;
        _totalGastos = sum;
      });
    } catch (e) {
      debugPrint('Error fetching gastos: $e');
      setState(() { _gastos = []; _totalGastos = 0.0; });
    } finally {
      setState(() => _isLoading = false);
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
    final sucursal = rec['sucursal'] ?? '';
    final total = double.tryParse(rec['Gasto']?.toString().replaceAll('\$', '').replaceAll('-', '').replaceAll(',', '.').trim() ?? '') ??
        double.tryParse((rec['total'] ?? 0).toString().replaceAll(',', '.')) ??
        double.tryParse((rec['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ??
        0.0;
    
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
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_outward_rounded, color: Colors.white, size: 20),
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
                      '-\$${formatMoney(total)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _detailRow('Monto del gasto', '\$${formatMoney(total)}'),
                if (rec['QuienRegistro'] != null) ...[
                  const SizedBox(height: 8),
                  _detailRow('Registrado por', rec['QuienRegistro'].toString(), isLabel: true),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Detalle de Gastos', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
            Text(widget.sucursalLabel, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _gastos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 48, color: Colors.black26),
                      SizedBox(height: 12),
                      Text('No hay gastos en este periodo', style: TextStyle(color: Colors.black54, fontSize: 14)),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total de Gastos', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text('\$${formatMoney(_totalGastos)}', style: TextStyle(color: Colors.red.shade700, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final rec = _gastos[i];
                            final fecha = rec['fecha'] != null ? DateTime.parse(rec['fecha']) : null;
                            final total = double.tryParse(rec['Gasto']?.toString().replaceAll('\$', '').replaceAll('-', '').replaceAll(',', '.').trim() ?? '') ??
                                double.tryParse((rec['total'] ?? 0).toString().replaceAll(',', '.')) ??
                                double.tryParse((rec['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ??
                                0.0;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _showDetails(rec),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: Icon(Icons.arrow_outward_rounded, color: Colors.red.shade400, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Gasto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                            if (fecha != null)
                                              Text(intl.DateFormat('d MMM HH:mm').format(fecha), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                          ],
                                        ),
                                      ),
                                      Text('-\$${formatMoney(total)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _gastos.length,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
