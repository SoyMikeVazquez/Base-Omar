import 'package:flutter/material.dart';
import 'package:totalpro/utils/formatters.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
//  Chart Painter  (línea blanca sobre bg oscuro)
// ─────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final TextDirection textDirection;

  _LineChartPainter(
    this.values, {
    required this.labels,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
    if (points.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, size.height - 20);
      fillPath.lineTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cpX = (prev.dx + curr.dx) / 2;
        fillPath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      }
      fillPath.lineTo(points.last.dx, size.height - 20);
      fillPath.lineTo(points.first.dx, size.height - 20);

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
    final labelStyle = const TextStyle(
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
class PersonalFinanceKpisScreen extends StatefulWidget {
  final String personalId;
  final String personalName;
  final String personalRole;
  final String? fotoPerfil;
  final bool mostrarFoto;

  const PersonalFinanceKpisScreen({
    super.key,
    required this.personalId,
    required this.personalName,
    required this.personalRole,
    this.fotoPerfil,
    this.mostrarFoto = true,
  });

  @override
  State<PersonalFinanceKpisScreen> createState() => _PersonalFinanceKpisScreenState();
}

enum _Period { today, week, month, custom }
enum _ChartGranularity { daily, monthly, yearly }

class _ChartData {
  final List<double> values;
  final List<String> labels;
  final _ChartGranularity granularity;
  const _ChartData(this.values, this.labels, this.granularity);
}

class _PersonalFinanceKpisScreenState extends State<PersonalFinanceKpisScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Data lists
  List<Map<String, dynamic>> _recordsFinanzas = [];
  List<Map<String, dynamic>> _recordsOrdenes = [];
  List<Map<String, dynamic>> _recordsCitas = [];
  List<Map<String, dynamic>> _assignedSupplies = [];

  // Filter totals
  double _totalServices = 0.0;
  double _totalExtras = 0.0;
  double _totalExpenses = 0.0;
  double _totalProducts = 0.0;
  int _totalCitasCount = 0;
  int _totalSuppliesQty = 0;

  // Date range
  late DateTime _start;
  late DateTime _end;
  _Period _activePeriod = _Period.today;

  // Tab view controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _applyPeriod(_Period.today);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Periodo ──────────────────────────────────
  void _applyPeriod(_Period period) {
    final now = DateTime.now();
    setState(() {
      _activePeriod = period;
      _end = now;
      switch (period) {
        case _Period.today:
          _start = DateTime(now.year, now.month, now.day);
          break;
        case _Period.week:
          _start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          break;
        case _Period.month:
          _start = DateTime(now.year, now.month, 1);
          break;
        case _Period.custom:
          break;
      }
    });
    _fetchKpiData();
  }

  // ── Fetch Data ────────────────────────────────
  Future<void> _fetchKpiData() async {
    setState(() => _isLoading = true);
    try {
      final startStr = _start.toIso8601String();
      final endStr = _end.toIso8601String();
      final startDateOnly = startStr.split('T')[0];
      final endDateOnly = endStr.split('T')[0];

      // Fetch FinanzasPersonal, OrdenesProductos, Citas, and InventarioDiario in parallel
      final futures = await Future.wait([
        // 1. FinanzasPersonal (Servicios, montos extras, gastos)
        _supabase
            .from('FinanzasPersonal')
            .select()
            .eq('personalID', widget.personalId)
            .gte('fecha', startStr)
            .lte('fecha', endStr)
            .order('fecha', ascending: false),
        // 2. OrdenesProductos (Ventas de productos)
        _supabase
            .from('OrdenesProductos')
            .select()
            .eq('personal_id', widget.personalId)
            .gte('fecha', startStr)
            .lte('fecha', endStr)
            .order('fecha', ascending: false),
        // 3. Citas (Citas totales filtrando por barberoID)
        _supabase
            .from('Citas')
            .select('''
              *,
              clientes (nombre, telefono, correo),
              Services (nameService, Price)
            ''')
            .eq('barberoID', widget.personalId)
            .gte('fecha', startDateOnly)
            .lte('fecha', endDateOnly)
            .neq('estatus', 'Cancelada')
            .order('fecha', ascending: false),
        // 4. InventarioDiario (Para insumos y asignaciones de stock)
        _supabase
            .from('InventarioDiario')
            .select()
            .gte('fecha', startDateOnly)
            .lte('fecha', endDateOnly)
            .order('fecha', ascending: false),
      ]);

      final rawFinanzas = List<Map<String, dynamic>>.from(futures[0]);
      final rawOrdenes = List<Map<String, dynamic>>.from(futures[1]);
      final rawCitas = List<Map<String, dynamic>>.from(futures[2]);
      final rawInv = List<Map<String, dynamic>>.from(futures[3]);

      // Calculate totals
      double servicesSum = 0.0;
      double extrasSum = 0.0;
      double expensesSum = 0.0;

      for (final r in rawFinanzas) {
        final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
        if (isGasto) {
          final gastoMonto = double.tryParse(r['Gasto']?.toString().replaceAll('\$', '').replaceAll('-', '').replaceAll(',', '.').trim() ?? '') ??
              double.tryParse((r['total'] ?? 0).toString().replaceAll(',', '.')) ??
              double.tryParse((r['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ??
              0.0;
          expensesSum += gastoMonto;
        } else {
          servicesSum += double.tryParse((r['suma_servicios'] ?? 0).toString().replaceAll(',', '.')) ?? 0.0;
          extrasSum += double.tryParse((r['montos_extras'] ?? 0).toString().replaceAll(',', '.')) ?? 0.0;
        }
      }

      double productsSum = 0.0;
      for (final r in rawOrdenes) {
        productsSum += double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
      }

      // Filter assigned supplies
      final List<Map<String, dynamic>> suppliesAssigned = [];
      int suppliesQty = 0;
      for (final inv in rawInv) {
        final rawAsignaciones = inv['asignacion_personal'];
        if (rawAsignaciones is List) {
          for (final a in rawAsignaciones) {
            if (a is Map && a['personal_id']?.toString() == widget.personalId) {
              final qty = int.tryParse(a['cantidad']?.toString() ?? '0') ?? 0;
              suppliesQty += qty;
              suppliesAssigned.add({
                'id': inv['id'],
                'nombre_producto': inv['nombre_producto'] ?? 'Insumo',
                'cantidad': qty,
                'fecha': inv['fecha'] ?? '',
              });
            }
          }
        }
      }

      setState(() {
        _recordsFinanzas = rawFinanzas;
        _recordsOrdenes = rawOrdenes;
        _recordsCitas = rawCitas;
        _assignedSupplies = suppliesAssigned;

        _totalServices = servicesSum;
        _totalExtras = extrasSum;
        _totalExpenses = expensesSum;
        _totalProducts = productsSum;
        _totalCitasCount = rawCitas.length;
        _totalSuppliesQty = suppliesQty;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching personal financial KPIs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _totalIngresos => _totalServices + _totalExtras + _totalProducts;

  _ChartGranularity get _granularity {
    final diff = _end.difference(_start).inDays;
    if (diff > 730) return _ChartGranularity.yearly;
    if (diff > 90) return _ChartGranularity.monthly;
    return _ChartGranularity.daily;
  }

  _ChartData _chartDataPoints() {
    final gran = _granularity;
    switch (gran) {
      case _ChartGranularity.daily:
        return _groupDaily();
      case _ChartGranularity.monthly:
        return _groupMonthly();
      case _ChartGranularity.yearly:
        return _groupYearly();
    }
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
      // Sum services/extras (exclude expenses)
      for (final r in _recordsFinanzas) {
        if (r['fecha'] == null) continue;
        final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
        if (isGasto) continue;

        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == day.year && f.month == day.month && f.day == day.day) {
            s += double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;
          }
        } catch (_) {}
      }
      // Sum product orders
      for (final r in _recordsOrdenes) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == day.year && f.month == day.month && f.day == day.day) {
            s += double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
          }
        } catch (_) {}
      }
      return s;
    }).toList();
    final labels = days.map((d) => intl.DateFormat('d/MM').format(d)).toList();
    return _ChartData(values, labels, _ChartGranularity.daily);
  }

  _ChartData _groupMonthly() {
    final months = <DateTime>[];
    var cur = DateTime(_start.year, _start.month, 1);
    final endMonth = DateTime(_end.year, _end.month, 1);
    while (!cur.isAfter(endMonth)) {
      months.add(cur);
      cur = DateTime(cur.year, cur.month + 1, 1);
    }
    final values = months.map((m) {
      double s = 0;
      for (final r in _recordsFinanzas) {
        if (r['fecha'] == null) continue;
        final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
        if (isGasto) continue;

        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == m.year && f.month == m.month) {
            s += double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;
          }
        } catch (_) {}
      }
      for (final r in _recordsOrdenes) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == m.year && f.month == m.month) {
            s += double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
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
      for (final r in _recordsFinanzas) {
        if (r['fecha'] == null) continue;
        final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
        if (isGasto) continue;

        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == y) {
            s += double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;
          }
        } catch (_) {}
      }
      for (final r in _recordsOrdenes) {
        if (r['fecha'] == null) continue;
        try {
          final f = DateTime.parse(r['fecha']);
          if (f.year == y) {
            s += double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
          }
        } catch (_) {}
      }
      return s;
    }).toList();
    final labels = years.map((y) => y.toString()).toList();
    return _ChartData(values, labels, _ChartGranularity.yearly);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
          'Finanzas: ${widget.personalName}',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              onRefresh: _fetchKpiData,
              color: Colors.black,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Hero Header Card (Name, Avatar, Balance)
                  SliverToBoxAdapter(child: _buildHeroCard()),

                  // 2. Date Filter Pills
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: _buildPeriodPills(),
                    ),
                  ),

                  // 3. Main KPI Metrics Row (Citas, Insumos)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildKpisRow(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // 4. Line Chart Trend
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildChartCard(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // 5. Tabs Segmented Section (Servicios, Productos, Insumos, Citas)
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.black38,
                        indicatorColor: Colors.black,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(text: 'Servicios'),
                          Tab(text: 'Ventas'),
                          Tab(text: 'Insumos'),
                          Tab(text: 'Citas'),
                        ],
                      ),
                    ),
                  ),

                  // 6. Tab Content Lists
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: Container(
                      color: Colors.white,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildServicesTab(),
                          _buildProductsTab(),
                          _buildSuppliesTab(),
                          _buildCitasTab(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    final netIncome = _totalIngresos;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.white.withValues(alpha: 0.1),
                  child: (widget.fotoPerfil != null && widget.mostrarFoto)
                      ? Image.network(widget.fotoPerfil!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarPlaceholder())
                      : _avatarPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.personalName,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.personalRole,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INGRESOS',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${formatMoney(_totalIngresos, decimalDigits: 0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(width: 1, height: 35, color: Colors.white.withValues(alpha: 0.15)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GASTOS',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${formatMoney(_totalExpenses, decimalDigits: 0)}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(width: 1, height: 35, color: Colors.white.withValues(alpha: 0.15)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BALANCE NETO',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${formatMoney(netIncome, decimalDigits: 0)}',
                    style: TextStyle(color: netIncome >= 0 ? Colors.green : Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Center(
        child: Text(
          widget.personalName.trim().isEmpty ? '?' : widget.personalName.trim()[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      );

  Widget _buildPeriodPills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    final now = DateTime.now();
                    setState(() {
                      _activePeriod = _Period.custom;
                      _start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
                      _end = now;
                    });
                    _fetchKpiData();
                  }
                },
                icon: Icons.tune_rounded,
              ),
            ],
          ),
        ),
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
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black38, letterSpacing: 0.5),
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
                                  _fetchKpiData();
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
                                  _fetchKpiData();
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

  Widget _buildKpisRow() {
    return Row(
      children: [
        Expanded(
          child: _KpiMetricCard(
            icon: Icons.calendar_today_rounded,
            label: 'Citas Hechas',
            value: '$_totalCitasCount',
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiMetricCard(
            icon: Icons.inventory_2_outlined,
            label: 'Insumos Asignados',
            value: '$_totalSuppliesQty',
            color: Colors.purpleAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    final chartData = _chartDataPoints();
    final hasTotals = chartData.values.isNotEmpty && chartData.values.any((v) => v > 0);

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
                'Desempeño de ingresos',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                intl.DateFormat('d/MM').format(_start),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Text(' → ', style: TextStyle(color: Colors.white24, fontSize: 11)),
              Text(
                intl.DateFormat('d/MM').format(_end),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasTotals)
            const SizedBox(
              height: 130,
              child: Center(
                child: Text('Sin ingresos registrados en este periodo', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: CustomPaint(
                size: const Size(double.infinity, 130),
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

  Widget _buildServicesTab() {
    final services = _recordsFinanzas.where((r) {
      final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
      return !isGasto;
    }).toList();

    if (services.isEmpty) return _emptyState('No hay servicios registrados');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final r = services[index];
        final fecha = r['fecha'] != null ? DateTime.parse(r['fecha'].toString()).toLocal() : null;
        final isGasto = (r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty) || (r['descripcion_extras'] == 'Gasto registrado');
        final total = double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;
        final formaPago = r['formadepago'] as String? ?? 'En efectivo';
        final sucursal = r['sucursal'] as String? ?? '';
        final serviciosDetalle = r['servicios_detalle'] as List? ?? [];
        final itemsCount = serviciosDetalle.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: const Color(0xFFF2F2F7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              fecha != null ? intl.DateFormat('dd/MM/yy · HH:mm').format(fecha) : 'Sin fecha',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '$itemsCount servicio${itemsCount != 1 ? 's' : ''} • $formaPago',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                if (sucursal.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Sucursal: $sucursal', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                ],
              ],
            ),
            trailing: Text(
              '\$${formatMoney(total, decimalDigits: 0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    if (_recordsOrdenes.isEmpty) return _emptyState('No hay ventas de productos');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recordsOrdenes.length,
      itemBuilder: (context, index) {
        final r = _recordsOrdenes[index];
        final fecha = r['fecha'] != null ? DateTime.parse(r['fecha'].toString()).toLocal() : null;
        final total = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
        final formaPago = r['formadepago'] as String? ?? 'En efectivo';
        final sucursal = r['sucursal'] as String? ?? '';
        final prodDetalle = r['productos_detalle'] as List? ?? [];
        final itemsCount = prodDetalle.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: const Color(0xFFF2F2F7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              fecha != null ? intl.DateFormat('dd/MM/yy · HH:mm').format(fecha) : 'Sin fecha',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '$itemsCount producto${itemsCount != 1 ? 's' : ''} • $formaPago',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                if (sucursal.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Sucursal: $sucursal', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                ],
              ],
            ),
            trailing: Text(
              '\$${formatMoney(total, decimalDigits: 0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuppliesTab() {
    if (_assignedSupplies.isEmpty) return _emptyState('No hay insumos asignados');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignedSupplies.length,
      itemBuilder: (context, index) {
        final r = _assignedSupplies[index];
        String dateFormatted = r['fecha']?.toString() ?? '';
        try {
          if (dateFormatted.isNotEmpty) {
            final parsed = DateTime.parse(dateFormatted);
            dateFormatted = intl.DateFormat('dd/MM/yyyy').format(parsed);
          }
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: const Color(0xFFF2F2F7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const Icon(Icons.inventory_2_outlined, color: Colors.purpleAccent),
            title: Text(
              r['nombre_producto'] ?? 'Insumo',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text('Fecha asignación: $dateFormatted', style: const TextStyle(fontSize: 11, color: Colors.black38)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(
                'x${r['cantidad']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCitasTab() {
    if (_recordsCitas.isEmpty) return _emptyState('No hay citas registradas');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recordsCitas.length,
      itemBuilder: (context, index) {
        final appointment = _recordsCitas[index];
        final clientData = appointment['clientes'] as Map<String, dynamic>? ?? {};
        final serviceData = appointment['Services'] as Map<String, dynamic>? ?? {};

        final clientName = clientData['nombre'] ?? appointment['nombreClienteTemporal'] ?? 'Cliente';
        final serviceName = serviceData['nameService'] ?? appointment['Servicios'] ?? 'Servicio';
        final timeStart = appointment['horaInicio'] ?? '--:--';
        final rawPrice = appointment['precioFinal'] ?? appointment['precioCobrado'] ?? 0;
        final priceStr = '\$$rawPrice';
        final date = appointment['fecha'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: const Color(0xFFF2F2F7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              clientName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(serviceName, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 2),
                Text('Fecha: $date · Hora: $timeStart', style: const TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
            trailing: Text(
              priceStr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_rounded, size: 40, color: Colors.black26),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.black38, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Helper Widgets
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
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: active ? Colors.white : Colors.black54),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

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
      initialDate: dateTime.isAfter(last) ? last : (dateTime.isBefore(first) ? first : dateTime),
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

    onPick(DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      0,
      0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = intl.DateFormat('dd/MM/yy');

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
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(dateFmt.format(dateTime), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
