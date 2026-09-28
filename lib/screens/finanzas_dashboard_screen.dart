import 'package:flutter/material.dart';
import 'package:totalpro/utils/formatters.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/finanzas_actions.dart';

// ─────────────────────────────────────────────
//  Chart Painter  (línea blanca sobre bg oscuro)
// ─────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels; // etiquetas para el eje X (primer y úiltimo punto)
  final TextDirection textDirection;

  _LineChartPainter(
    this.values, {
    required this.labels,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Guard: necesitamos al menos 2 puntos para trazar la línea
    if (values.isEmpty) return;

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final n = values.length;

    List<Offset> points = [];
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : (i / (n - 1)) * size.width;
      final y = maxVal > 0
          ? size.height - 20 - (values[i] / maxVal) * (size.height - 40)
          : size.height - 20;
      points.add(Offset(x, y));
    }

    // --- Gradiente de relleno bajo la línea ---
    // Usa las mismas curvas bezier que la línea para que el fill sea preciso
    if (points.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, size.height - 20); // base izquierda
      fillPath.lineTo(points.first.dx, points.first.dy);  // sube al primer punto
      for (var i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cpX = (prev.dx + curr.dx) / 2;
        fillPath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      }
      fillPath.lineTo(points.last.dx, size.height - 20);  // baja a base derecha
      fillPath.lineTo(points.first.dx, size.height - 20); // cierra por la base

      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
      );
      final fillPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // --- Línea principal ---
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        // Curva suave entre puntos
        final prev = points[i - 1];
        final curr = points[i];
        final cpX = (prev.dx + curr.dx) / 2;
        linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // --- Puntos en cada día ---
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (final p in points) {
      canvas.drawCircle(p, 5, dotBorderPaint);
      canvas.drawCircle(p, 3, dotPaint);
    }

    // --- Etiquetas de fecha (sólo primera y última) ---
    final labelStyle = TextStyle(
      color: Colors.white60,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    void drawLabel(String text, double x, {bool rightAlign = false}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: textDirection,
      );
      tp.layout();
      double dx = x - (rightAlign ? tp.width : 0);
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - 16));
    }

    if (n >= 1 && labels.isNotEmpty) {
      drawLabel(labels.first, 0);
    }
    if (n >= 2 && labels.length >= 2) {
      drawLabel(labels.last, size.width, rightAlign: true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class FinanzasDashboardScreen extends StatefulWidget {
  final String personalId;
  const FinanzasDashboardScreen({super.key, required this.personalId});

  @override
  State<FinanzasDashboardScreen> createState() =>
      _FinanzasDashboardScreenState();
}

enum _Period { today, week, month, custom }

/// Granularidad de la gráfica según el rango de fechas
enum _ChartGranularity { individual, daily, monthly, yearly }

/// Resultado de agrupación para la gráfica
class _ChartData {
  final List<double> values;
  final List<String> labels; // etiqueta por cada nodo
  final _ChartGranularity granularity;
  const _ChartData(this.values, this.labels, this.granularity);
}

class _FinanzasDashboardScreenState extends State<FinanzasDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
   // 0 = Servicios, 1 = Productos
  String? _selectedPaymentMethod; // null = all, 'efectivo', 'tarjeta', 'transferencia', 'otro'

  double _globalServicesSum = 0.0;
  double _globalExtrasSum = 0.0;
  double _globalProductsSum = 0.0;
  double _cajaGlobal = 0.0;
  double _balanceGlobal = 0.0;
  double _cashIncomeGlobal = 0.0;
  double _expensesGlobal = 0.0;

  late DateTime _start;
  late DateTime _end;
  _Period _activePeriod = _Period.today;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _applyPeriod(_Period.today);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Periodo ──────────────────────────────────
  void _applyPeriod(_Period period) {
    final now = DateTime.now();
    setState(() {
      _activePeriod = period;
      _selectedPaymentMethod = null;
      _end = now;
      switch (period) {
        case _Period.today:
          _start = DateTime(now.year, now.month, now.day);
          break;
        case _Period.week:
          _start = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 6));
          break;
        case _Period.month:
          _start = DateTime(now.year, now.month, 1);
          break;
        case _Period.custom:
          break; // manejado en _pickRange
      }
    });
    _fetchRecords();
  }

  // ── Data ─────────────────────────────────────
  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    _fadeCtrl.reset();
    try {
      if (_activePeriod != _Period.custom) {
        final now = DateTime.now();
        _end = now;
        switch (_activePeriod) {
          case _Period.today:
            _start = DateTime(now.year, now.month, now.day);
            break;
          case _Period.week:
            _start = DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 6));
            break;
          case _Period.month:
            _start = DateTime(now.year, now.month, 1);
            break;
          case _Period.custom:
            break;
        }
      }

      final startStr = _start.toIso8601String();
      final endStr = _end.toIso8601String();

      final futures = await Future.wait([
        _supabase
            .from('FinanzasPersonal')
            .select()
            .eq('personalID', widget.personalId)
            .gte('fecha', startStr)
            .lte('fecha', endStr)
            .order('fecha', ascending: false),
        _supabase
            .from('OrdenesProductos')
            .select()
            .eq('personal_id', widget.personalId)
            .gte('fecha', startStr)
            .lte('fecha', endStr)
            .order('fecha', ascending: false),
      ]);

      final finanzasResp = List<Map<String, dynamic>>.from(futures[0]);
      final ordenesResp = List<Map<String, dynamic>>.from(futures[1]);

      double sumServ = 0.0;
      double sumExt = 0.0;
      double totalIncome = 0.0;
      double cashIncome = 0.0;
      double expenses = 0.0;

      for (var r in finanzasResp) {
        sumServ += double.tryParse((r['suma_servicios'] ?? 0).toString().replaceAll(',', '.')) ?? 0.0;
        sumExt += double.tryParse((r['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ?? 0.0;
        
        final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
        final gastoMonto = double.tryParse(r['Gasto']?.toString().replaceAll('\$', '').replaceAll('-', '').replaceAll(',', '.').trim() ?? '') ??
            double.tryParse((r['total'] ?? 0).toString().replaceAll(',', '.')) ??
            double.tryParse((r['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ??
            0.0;
        final total = isGasto ? gastoMonto : (double.tryParse((r['total'] ?? 0).toString().replaceAll(',', '.')) ?? 0.0);
        final formaPago = (r['formadepago'] as String? ?? '').toLowerCase().trim();

        if (isGasto) {
          expenses += total;
        } else {
          totalIncome += total;
          if (formaPago.contains('efectivo')) {
            cashIncome += total;
          }
        }
      }

      double sumProd = 0.0;
      for (var r in ordenesResp) {
        final totalProd = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
        sumProd += totalProd;
        
        final formaPago = (r['formadepago'] as String? ?? '').toLowerCase().trim();
        totalIncome += totalProd;
        if (formaPago.contains('efectivo')) {
          cashIncome += totalProd;
        }
      }

      double cajaTemp = cashIncome - expenses;
      double balanceTemp = totalIncome / 2;

      setState(() {
        _globalServicesSum = sumServ;
        _globalExtrasSum = sumExt;
        _globalProductsSum = sumProd;
        _cajaGlobal = cajaTemp;
        _balanceGlobal = balanceTemp;
        _cashIncomeGlobal = cashIncome;
        _expensesGlobal = expenses;

        _records = [...finanzasResp, ...ordenesResp];
        _records.sort((a, b) {
          final fa = a['fecha'] != null ? DateTime.parse(a['fecha']) : DateTime.fromMillisecondsSinceEpoch(0);
          final fb = b['fecha'] != null ? DateTime.parse(b['fecha']) : DateTime.fromMillisecondsSinceEpoch(0);
          return fb.compareTo(fa);
        });
      });
    } catch (e) {
      debugPrint('Error fetching finanzas: $e');
      setState(() {
        _records = [];
        _globalServicesSum = 0.0;
        _globalExtrasSum = 0.0;
        _globalProductsSum = 0.0;
        _cajaGlobal = 0.0;
        _balanceGlobal = 0.0;
        _cashIncomeGlobal = 0.0;
        _expensesGlobal = 0.0;
      });
    } finally {
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  // ── Cómputos ──────────────────────────────────


  double get _totalSum {
    double s = 0;
    for (var r in _records) {
      s += (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0) + (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0);
    }
    return s;
  }

  double get _sumServicios {
    double s = 0;
    for (var r in _records) {
      s += double.tryParse((r['suma_servicios'] ?? 0).toString()) ?? 0.0;
    }
    return s * 0.50; // Comisión del 50%
  }

  double get _sumMontosExtras {
    double s = 0;
    for (var r in _records) {
      s += double.tryParse((r['montos_extras'] ?? 0).toString()) ?? 0.0;
    }
    return s;
  }

  int get _totalUnidadesProductos {
    int total = 0;
    for (var r in _records) {
      final list = r['productos_detalle'] as List? ?? [];
      for (var p in list) {
        total += int.tryParse((p['cantidad'] ?? 0).toString()) ?? 0;
      }
    }
    return total;
  }

  // ── Granularidad dinámica de la gráfica ────────────
  _ChartGranularity get _granularity {
    if (_activePeriod == _Period.today) return _ChartGranularity.individual;
    final diff = _end.difference(_start).inDays;
    if (diff > 730) return _ChartGranularity.yearly;
    if (diff > 90) return _ChartGranularity.monthly;
    return _ChartGranularity.daily;
  }

  /// Agrupa los registros según la granularidad activa
  /// y retorna valores + etiquetas para cada nodo de la gráfica.
  _ChartData _chartDataPoints() {
    final gran = _granularity;
    switch (gran) {
      case _ChartGranularity.individual:
        return _groupIndividual();
      case _ChartGranularity.daily:
        return _groupDaily();
      case _ChartGranularity.monthly:
        return _groupMonthly();
      case _ChartGranularity.yearly:
        return _groupYearly();
    }
  }


  _ChartData _groupIndividual() {
    final sorted = List<Map<String, dynamic>>.from(_records)
      ..sort((a, b) {
        final fa = a['fecha'] != null ? DateTime.tryParse(a['fecha']) ?? DateTime(2000) : DateTime(2000);
        final fb = b['fecha'] != null ? DateTime.tryParse(b['fecha']) ?? DateTime(2000) : DateTime(2000);
        return fa.compareTo(fb);
      });
      
    final values = <double>[];
    final labels = <String>[];
    
    for (final r in sorted) {
      if (r['fecha'] == null) continue;
      try {
        final f = DateTime.parse(r['fecha']);
        final serv = double.tryParse((r['suma_servicios'] ?? 0).toString()) ?? 0.0;
            final ext = double.tryParse((r['montos_extras'] ?? 0).toString()) ?? 0.0;
            final prod = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
            values.add((serv * 0.50) + ext + prod);
        labels.add(intl.DateFormat('HH:mm').format(f));
      } catch (_) {}
    }
    
    if (values.isEmpty) {
      return _ChartData([0], [''], _ChartGranularity.individual);
    }
    
    return _ChartData(values, labels, _ChartGranularity.individual);
  }

  _ChartData _groupDaily() {
    final startDate = DateTime(_start.year, _start.month, _start.day);
    final endDate = DateTime(_end.year, _end.month, _end.day);
    final days = <DateTime>[];
    for (var d = startDate; !d.isAfter(endDate); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    final values = days.map((day) {
      double s = 0;
      for (final r in _records) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == day.year && f.month == day.month && f.day == day.day) {
            final serv = double.tryParse((r['suma_servicios'] ?? 0).toString()) ?? 0.0;
            final ext = double.tryParse((r['montos_extras'] ?? 0).toString()) ?? 0.0;
            final prod = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
            s += (serv * 0.50) + ext + prod;
          }
        } catch (_) {}
      }
      return s;
    }).toList();
    final labels = days.map((d) => intl.DateFormat('d/MM').format(d)).toList();
    return _ChartData(values, labels, _ChartGranularity.daily);
  }

  _ChartData _groupMonthly() {
    // Genera una lista de primeros días de mes en el rango
    final months = <DateTime>[];
    var cur = DateTime(_start.year, _start.month, 1);
    final endMonth = DateTime(_end.year, _end.month, 1);
    while (!cur.isAfter(endMonth)) {
      months.add(cur);
      cur = DateTime(cur.year, cur.month + 1, 1);
    }
    final values = months.map((m) {
      double s = 0;
      for (final r in _records) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == m.year && f.month == m.month) {
            final serv = double.tryParse((r['suma_servicios'] ?? 0).toString()) ?? 0.0;
            final ext = double.tryParse((r['montos_extras'] ?? 0).toString()) ?? 0.0;
            final prod = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
            s += (serv * 0.50) + ext + prod;
          }
        } catch (_) {}
      }
      return s;
    }).toList();
    final labels = months.map((m) => intl.DateFormat('MM/yy').format(m)).toList();
    return _ChartData(values, labels, _ChartGranularity.monthly);
  }

  _ChartData _groupYearly() {
    final years = <int>[];
    for (var y = _start.year; y <= _end.year; y++) {
      years.add(y);
    }
    final values = years.map((y) {
      double s = 0;
      for (final r in _records) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == y) {
            final serv = double.tryParse((r['suma_servicios'] ?? 0).toString()) ?? 0.0;
            final ext = double.tryParse((r['montos_extras'] ?? 0).toString()) ?? 0.0;
            final prod = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
            s += (serv * 0.50) + ext + prod;
          }
        } catch (_) {}
      }
      return s;
    }).toList();
    final labels = years.map((y) => y.toString()).toList();
    return _ChartData(values, labels, _ChartGranularity.yearly);
  }

  void _showDetails(Map<String, dynamic> rec) {
    final fecha =
        rec['fecha'] != null ? DateTime.parse(rec['fecha']) : null;
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
    final extras = isService
        ? (double.tryParse((rec['montos_extras'] ?? 0).toString()) ?? 0.0)
        : 0.0;
    final serviciosSum = isService
        ? (double.tryParse((rec['suma_servicios'] ?? 0).toString()) ?? 0.0)
        : 0.0;

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
            top: 12,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isGasto ? Colors.red : Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isGasto ? Icons.arrow_outward_rounded : _paymentIcon(formaPago),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fecha != null
                                ? intl.DateFormat(
                                    'EEEE d \' de \' MMMM · HH:mm',
                                  ).format(fecha)
                                : 'Sin fecha',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sucursal,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      isGasto ? '-\$${formatMoney(total)}' : '\$${formatMoney(total)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isGasto ? Colors.red : Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Desglose
                if (isGasto) ...[
                  _detailRow('Monto del gasto', '\$${formatMoney(total)}'),
                ] else if (isService) ...[
                  _detailRow('Servicios', '\$${formatMoney(serviciosSum)}'),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Montos extras',
                    '\$${formatMoney(extras)}',
                  ),
                ] else ...[
                  _detailRow('Venta de productos', '\$${formatMoney(total)}'),
                ],
                const SizedBox(height: 8),
                _detailRow(
                  'Forma de pago',
                  formaPago,
                  isLabel: true,
                ),

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

                // Detalle de Items
                if (isGasto) ...[
                  const Text(
                    'Detalle del gasto',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rec['descripcion_extras'] as String? ?? 'Gasto registrado',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '\$${formatMoney(total)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isService) ...[
                  if (servicios.isNotEmpty) ...[
                    const Text(
                      'Servicios realizados',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...servicios.map((s) {
                      final name = s['name'] ?? s['nombre'] ?? 'Servicio';
                      final price = s['price'] ?? s['precio'] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '\$${price.toString()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else
                    const Text(
                      'Sin servicios registrados',
                      style: TextStyle(color: Colors.black38, fontSize: 14),
                    ),
                ] else ...[
                  if (productos.isNotEmpty) ...[
                    const Text(
                      'Productos vendidos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...productos.map((p) {
                      final name = p['nombre'] ?? p['NombreProducto'] ?? 'Producto';
                      final price = p['precio_unitario'] ?? 0.0;
                      final qty = p['cantidad'] ?? 1;
                      final sub = p['subtotal'] ?? (price * qty);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$name (x$qty)',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '\$${sub.toString()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else
                    const Text(
                      'Sin productos registrados',
                      style: TextStyle(color: Colors.black38, fontSize: 14),
                    ),
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

  Widget _detailRow(String label, String value, {bool isLabel = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const Spacer(),
        if (isLabel)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────
  IconData _paymentIcon(String forma) {
    switch (forma.toLowerCase()) {
      case 'tarjeta':
        return Icons.credit_card_rounded;
      case 'transferencia':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _periodLabel() {
    switch (_activePeriod) {
      case _Period.today:
        return 'Hoy';
      case _Period.week:
        return 'Últimos 7 días';
      case _Period.month:
        return 'Este mes';
      case _Period.custom:
        return '${intl.DateFormat('d/MM').format(_start)} – '
            '${intl.DateFormat('d/MM').format(_end)}';
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: RefreshIndicator(
        onRefresh: _fetchRecords,
        color: Colors.black,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          // ── Hero Header ──────────────────────
          SliverToBoxAdapter(child: _buildHeroHeader(mq)),

          // ── Periodo Pills ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildPeriodPills(),
            ),
          ),

          // ── Métricas Cards ────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMetricCards(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Gráfica ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildChartCard(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Segmentación por Método de Pago ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildPaymentMethodsSummary(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Lista de registros ────────────────
          Builder(builder: (context) {
            // Apply payment method filter
            final filteredRecords = _selectedPaymentMethod == null
                ? _records
                : _records.where((r) {
                    final fp = (r['formadepago'] as String? ?? '').toLowerCase().trim();
                    switch (_selectedPaymentMethod) {
                      case 'efectivo':
                        return fp.contains('efectivo');
                      case 'tarjeta':
                        return fp.contains('tarjeta');
                      case 'transferencia':
                        return fp.contains('transferencia');
                      case 'otro':
                        return !fp.contains('efectivo') && !fp.contains('tarjeta') && !fp.contains('transferencia');
                      default:
                        return true;
                    }
                  }).toList();

            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Historial de Registros',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_selectedPaymentMethod != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _selectedPaymentMethod = null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedPaymentMethod == 'efectivo' ? 'Efectivo'
                                        : _selectedPaymentMethod == 'tarjeta' ? 'Tarjeta'
                                        : _selectedPaymentMethod == 'transferencia' ? 'Transferencia'
                                        : 'Otro',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black54),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.close_rounded, size: 12, color: Colors.black45),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${filteredRecords.length} en total',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SliverToBoxAdapter(child: SizedBox(height: 10)),

          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              ),
            )
          else if (_records.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            Builder(builder: (context) {
              final filteredRecords = _selectedPaymentMethod == null
                  ? _records
                  : _records.where((r) {
                      final fp = (r['formadepago'] as String? ?? '').toLowerCase().trim();
                      switch (_selectedPaymentMethod) {
                        case 'efectivo':
                          return fp.contains('efectivo');
                        case 'tarjeta':
                          return fp.contains('tarjeta');
                        case 'transferencia':
                          return fp.contains('transferencia');
                        case 'otro':
                          return !fp.contains('efectivo') && !fp.contains('tarjeta') && !fp.contains('transferencia');
                        default:
                          return true;
                      }
                    }).toList();

              if (filteredRecords.isEmpty) {
                return SliverToBoxAdapter(child: _buildEmptyState());
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildRecordCard(filteredRecords[i]),
                    ),
                  ),
                  childCount: filteredRecords.length,
                ),
              );
            }),

          SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 24)),
        ],
      ),
    ),
  );
}

  // ── Hero Header ────────────────────────────────
  Widget _buildHeroHeader(MediaQueryData mq) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2E)],
        ),
      ),
      padding: EdgeInsets.only(
        top: mq.padding.top + 8,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppBar row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _fetchRecords,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Label periodo
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _periodLabel(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Totales (Izquierda: Activa, Derecha: General)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoading
                          ? '—'
                          : '\$${formatMoney(_globalServicesSum + _globalExtrasSum)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: Colors.white.withValues(alpha: 0.15),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _isLoading
                          ? '—'
                          : '\$${formatMoney(_globalProductsSum)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Productos',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

        ],
      ),
    );
  }

  // ── Period Pills ────────────────────────────────
  Widget _buildPeriodPills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila de pills (scrollable horizontal para pantallas pequeñas)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _PeriodPill(
                label: 'Hoy',
                active: _activePeriod == _Period.today,
                onTap: () => _applyPeriod(_Period.today),
              ),
              const SizedBox(width: 8),
              _PeriodPill(
                label: '7 días',
                active: _activePeriod == _Period.week,
                onTap: () => _applyPeriod(_Period.week),
              ),
              const SizedBox(width: 8),
              _PeriodPill(
                label: 'Mes',
                active: _activePeriod == _Period.month,
                onTap: () => _applyPeriod(_Period.month),
              ),
              const SizedBox(width: 8),
              _PeriodPill(
                label: 'Personalizado',
                active: _activePeriod == _Period.custom,
                onTap: () {
                  if (_activePeriod != _Period.custom) {
                    // Al activar, default: 7 días atrás → ahora
                    final now = DateTime.now();
                    setState(() {
                      _activePeriod = _Period.custom;
                      _start = DateTime(now.year, now.month, now.day)
                          .subtract(const Duration(days: 7));
                      _end = now;
                    });
                    _fetchRecords();
                  }
                },
                icon: Icons.tune_rounded,
              ),
            ],
          ),
        ),

        // Selectores inline — aparecen con animación cuando "Personalizado" está activo
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _activePeriod == _Period.custom
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rango personalizado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black38,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _DateTimePickerButton(
                                label: 'Inicio',
                                dateTime: _start,
                                onPick: (dt) {
                                  setState(() => _start = dt);
                                  _fetchRecords();
                                },
                                maxDate: DateTime.now(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DateTimePickerButton(
                                label: 'Fin',
                                dateTime: _end,
                                onPick: (dt) {
                                  setState(() => _end = dt);
                                  _fetchRecords();
                                },
                                minDate: _start,
                                maxDate: DateTime.now(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Métric Cards ────────────────────────────────
  Widget _buildMetricCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: _MetricCard(
              icon: Icons.receipt_long_rounded,
              label: 'Registros',
              value: '${_records.length}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: _MetricCard(
              icon: Icons.design_services_rounded,
              label: 'Servicios',
              value: '\$${formatMoney(_globalServicesSum, decimalDigits: 0)}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: _MetricCard(
              icon: Icons.shopping_bag_outlined,
              label: 'Productos',
              value: '\$${formatMoney(_globalProductsSum, decimalDigits: 0)}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: _MetricCard(
              icon: Icons.add_circle_outline_rounded,
              label: 'Extras',
              value: '\$${formatMoney(_globalExtrasSum, decimalDigits: 0)}',
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  // ── Segmentación por Método de Pago ──────────────────
  Widget _buildPaymentMethodsSummary() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    double cash = 0.0;
    double card = 0.0;
    double transfer = 0.0;
    double other = 0.0;

    for (var r in _records) {
      final isService = !r.containsKey('suma_productos');
      final isGasto = isService && ((r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado'));
      if (isGasto) continue; // Skip expenses

      final total = isService
          ? (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0)
          : (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0);

      final formaPago = (r['formadepago'] as String? ?? '').toLowerCase().trim();

      if (formaPago.contains('efectivo')) {
        cash += total;
      } else if (formaPago.contains('tarjeta')) {
        card += total;
      } else if (formaPago.contains('transferencia')) {
        transfer += total;
      } else {
        other += total;
      }
    }

    final items = [
      (
        'Efectivo',
        cash,
        Icons.payments_rounded,
        const Color(0xFF34C759),
      ),
      (
        'Tarjeta',
        card,
        Icons.credit_card_rounded,
        const Color(0xFF007AFF),
      ),
      (
        'Transferencia',
        transfer,
        Icons.swap_horiz_rounded,
        const Color(0xFFFF9500),
      ),
      (
        'Otro',
        other,
        Icons.more_horiz_rounded,
        const Color(0xFF8E8E93),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen por Método de Pago',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - 24) / 4;
            if (cardWidth > 80) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: items.map((item) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildPaymentMethodCard(item.$1, item.$2, item.$3, item.$4),
                  );
                }).toList(),
              );
            } else {
              final double gridWidth = (constraints.maxWidth - 10) / 2;
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: gridWidth,
                        child: _buildPaymentMethodCard(items[0].$1, items[0].$2, items[0].$3, items[0].$4),
                      ),
                      SizedBox(
                        width: gridWidth,
                        child: _buildPaymentMethodCard(items[1].$1, items[1].$2, items[1].$3, items[1].$4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: gridWidth,
                        child: _buildPaymentMethodCard(items[2].$1, items[2].$2, items[2].$3, items[2].$4),
                      ),
                      SizedBox(
                        width: gridWidth,
                        child: _buildPaymentMethodCard(items[3].$1, items[3].$2, items[3].$3, items[3].$4),
                      ),
                    ],
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),
        _buildCajaSummaryCard(),
      ],
    );
  }

  Widget _buildCajaSummaryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Efectivo en Caja',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Premium dark look
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Balance de la caja | Efectivo - Gastos',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                formatMoney(_cajaGlobal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '(Efectivo \$${formatMoney(_cashIncomeGlobal)} - Gastos \$${formatMoney(_expensesGlobal)})',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(String title, double amount, IconData icon, Color color) {
    final key = title == 'Efectivo' ? 'efectivo'
        : title == 'Tarjeta' ? 'tarjeta'
        : title == 'Transferencia' ? 'transferencia'
        : 'otro';
    final isActive = _selectedPaymentMethod == key;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = isActive ? null : key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.05),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isActive ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? color : Colors.black54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '\$${formatMoney(amount, decimalDigits: 0)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Chart Card ──────────────────────────────────
  Widget _buildChartCard() {
    final chartData = _chartDataPoints();
    final hasTotals = chartData.values.isNotEmpty && chartData.values.any((v) => v > 0);

    // Etiqueta de granularidad para mostrar en la card
    final String granLabel;
    switch (chartData.granularity) {
      case _ChartGranularity.individual:
        granLabel = 'Vista individual';
        break;
      case _ChartGranularity.daily:
        granLabel = 'Vista diaria';
        break;
      case _ChartGranularity.monthly:
        granLabel = 'Vista mensual';
        break;
      case _ChartGranularity.yearly:
        granLabel = 'Vista anual';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tendencia de ingresos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Badge de granularidad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  granLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                intl.DateFormat('d/MM').format(_start),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Text(
                ' → ',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
              Text(
                intl.DateFormat('d/MM').format(_end),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const SizedBox(
              height: 140,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white38,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (!hasTotals)
            const SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'Sin datos para mostrar',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: const Size(double.infinity, 140),
                painter: _LineChartPainter(
                  chartData.values,
                  labels: chartData.labels,
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Record Card ─────────────────────────────────
  Widget _buildRecordCard(Map<String, dynamic> r) {
    final fecha =
        r['fecha'] != null ? DateTime.parse(r['fecha']) : null;
    final isService = !r.containsKey('suma_productos');
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono de pago
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isGasto ? const Color(0xFFFBF2F2) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGasto
                    ? Icons.arrow_outward_rounded
                    : (isService ? _paymentIcon(formaPago) : Icons.shopping_bag_outlined),
                size: 20,
                color: isGasto ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fecha != null
                        ? intl.DateFormat('dd/MM · HH:mm').format(fecha)
                        : 'Sin fecha',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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

            // Total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isGasto ? '-\$${formatMoney(total)}' : '\$${formatMoney(total)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isGasto ? Colors.red : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formaPago,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black26,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: Colors.black26,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin registros en este periodo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cambia el periodo o agrega nuevos registros',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────

class _PeriodPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: active ? Colors.white : Colors.black54,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLoading;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
          const SizedBox(height: 2),
          isLoading
              ? Container(
                  width: 40,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _DateTimePickerButton
//  Botón compacto que muestra fecha+hora y abre
//  un date picker seguido de un time picker.
// ─────────────────────────────────────────────
class _DateTimePickerButton extends StatelessWidget {
  final String label;
  final DateTime dateTime;
  final ValueChanged<DateTime> onPick;
  final DateTime? minDate;
  final DateTime? maxDate;

  const _DateTimePickerButton({
    required this.label,
    required this.dateTime,
    required this.onPick,
    this.minDate,
    this.maxDate,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = minDate ?? DateTime(2020);
    final last = maxDate ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: dateTime.isAfter(last)
          ? last
          : (dateTime.isBefore(first) ? first : dateTime),
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Colors.black,
            surface: Color(0xFF1C1C1E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dateTime),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Colors.black,
            surface: Color(0xFF1C1C1E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !context.mounted) return;

    onPick(DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = intl.DateFormat('dd/MM/yy');
    final timeFmt = intl.DateFormat('HH:mm');

    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black38,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: Colors.black54,
                ),
                const SizedBox(width: 4),
                Text(
                  dateFmt.format(dateTime),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Colors.black38,
                ),
                const SizedBox(width: 4),
                Text(
                  timeFmt.format(dateTime),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
