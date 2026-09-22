import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/custom_text_field.dart';
import 'proveedores_stock_screen.dart';

class InventarioDiarioScreen extends StatefulWidget {
  const InventarioDiarioScreen({super.key});

  @override
  State<InventarioDiarioScreen> createState() => _InventarioDiarioScreenState();
}

class _InventarioDiarioScreenState extends State<InventarioDiarioScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  final Map<String, int> _editedStocks = {};
  
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Calendar properties
  final ScrollController _dateScrollController = ScrollController();
  final List<DateTime> _dates = [];

  // Latest supplier order (Pedido) properties
  Map<String, dynamic>? _latestPedido;
  bool _loadingPedido = true;

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadDailyInventory();
    _fetchLatestPedido();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(animate: false);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _dateScrollController.dispose();
    super.dispose();
  }

  void _generateDates() {
    _dates.clear();
    final today = DateTime.now();
    // Generamos fechas desde hace 30 días hasta dentro de 30 días
    for (int i = -30; i <= 30; i++) {
      _dates.add(today.add(Duration(days: i)));
    }
  }

  void _scrollToSelectedDate({bool animate = true}) {
    if (!_dateScrollController.hasClients) return;

    final index = _dates.indexWhere((date) =>
        date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day);

    if (index != -1) {
      const itemWidth = 72.0; // 60 ancho + 12 margen
      final screenWidth = MediaQuery.of(context).size.width;
      final offset = (index * itemWidth) - (screenWidth / 2) + 36.0;

      final maxScroll = _dateScrollController.position.maxScrollExtent;
      final targetScroll = offset.clamp(0.0, maxScroll);

      if (animate) {
        _dateScrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _dateScrollController.jumpTo(targetScroll);
      }
    }
  }

  Future<void> _loadDailyInventory() async {
    setState(() => _isLoading = true);
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      // 1. Fetch existing daily inventory for the selected date
      final resp = await _supabase
          .from('InventarioDiario')
          .select('*, Productos(categoria, imagen_url)')
          .eq('fecha', dateStr)
          .order('nombre_producto', ascending: true);

      final list = List<Map<String, dynamic>>.from(resp);

      // 2. If it's today and the list is empty, auto-generate from Productos
      final todayStr = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (list.isEmpty && dateStr == todayStr) {
        await _generateTodayInventory(dateStr);
      } else {
        if (mounted) {
          setState(() {
            _records = list;
            _editedStocks.clear();
            for (final r in list) {
              _editedStocks[r['id'].toString()] = r['stock'] ?? 0;
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading daily inventory: $e');
      _showSnackbar('Error al cargar inventario: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateTodayInventory(String dateStr) async {
    try {
      // 1. Fetch all current active products from catalog
      final prodsResp = await _supabase.from('Productos').select('id, nombre, stock');
      final products = List<Map<String, dynamic>>.from(prodsResp);

      if (products.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Find the most recent date in InventarioDiario before dateStr
      final latestDateResp = await _supabase
          .from('InventarioDiario')
          .select('fecha')
          .lt('fecha', dateStr)
          .order('fecha', ascending: false)
          .limit(1);

      Map<String, int> previousStockMap = {};

      if (latestDateResp.isNotEmpty) {
        final latestDate = latestDateResp[0]['fecha'] as String;
        // Fetch stocks for that date
        final prevInventoryResp = await _supabase
            .from('InventarioDiario')
            .select('producto_id, stock')
            .eq('fecha', latestDate);
        
        for (final item in prevInventoryResp) {
          final prodId = item['producto_id'].toString();
          final stock = item['stock'] as int? ?? 0;
          previousStockMap[prodId] = stock;
        }
      }

      // 3. Map products to today's inserts
      final inserts = products.map((p) {
        final prodId = p['id'].toString();
        // Use previous day's stock if available, else current catalog stock
        final startingStock = previousStockMap[prodId] ?? (p['stock'] ?? 0);
        
        return {
          'producto_id': p['id'],
          'nombre_producto': p['nombre'],
          'stock': startingStock,
          'fecha': dateStr,
        };
      }).toList();

      // 4. Perform insert
      await _supabase.from('InventarioDiario').insert(inserts);

      // Re-fetch now that it's created
      final resp = await _supabase
          .from('InventarioDiario')
          .select('*, Productos(categoria, imagen_url)')
          .eq('fecha', dateStr)
          .order('nombre_producto', ascending: true);

      if (mounted) {
        final list = List<Map<String, dynamic>>.from(resp);
        setState(() {
          _records = list;
          _editedStocks.clear();
          for (final r in list) {
            _editedStocks[r['id'].toString()] = r['stock'] ?? 0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating inventory: $e');
      _showSnackbar('Error al autogenerar inventario de hoy: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateDialog() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDailyInventory();
      _scrollToSelectedDate();
    }
  }

  Future<void> _saveStock(Map<String, dynamic> record, int newStock) async {
    final recordId = record['id'];
    final productId = record['producto_id'];
    final productName = record['nombre_producto'];

    setState(() => _isLoading = true);

    try {
      // 1. Update InventarioDiario
      await _supabase.from('InventarioDiario').update({
        'stock': newStock,
      }).eq('id', recordId);

      // 2. If it's today, update Productos to keep the main catalog in sync
      final todayStr = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(_selectedDate);
      if (dateStr == todayStr) {
        await _supabase.from('Productos').update({
          'stock': newStock,
        }).eq('id', productId);
      }

      // Update local original value
      final idx = _records.indexWhere((r) => r['id'] == recordId);
      if (idx != -1) {
        setState(() {
          _records[idx]['stock'] = newStock;
        });
      }

      _showSuccessSnackbar('Stock de "$productName" guardado con éxito ($newStock uds).');
    } catch (e) {
      _showSnackbar('Error al guardar stock: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLatestPedido() async {
    if (mounted) setState(() => _loadingPedido = true);
    try {
      final response = await _supabase
          .from('ProveedoresStock')
          .select()
          .not('productos_pedidos', 'is', null)
          .neq('productos_pedidos', '[]')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _latestPedido = response;
          _loadingPedido = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading latest pedido: $e');
      if (mounted) setState(() => _loadingPedido = false);
    }
  }

  void _showSnackbar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void _showSuccessSnackbar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_searchQuery.trim().isEmpty) {
      return _records;
    }
    return _records.where((r) {
      final name = (r['nombre_producto'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Inventario Diario',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Calendario Horizontal Superior
              _buildHorizontalCalendar(),

              // Buscador de productos
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: CustomTextField(
                  controller: _searchCtrl,
                  label: 'Buscar producto...',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),

              // Lista de productos
              _isLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: Colors.black)),
                    )
                  : _filteredRecords.isEmpty
                      ? SizedBox(height: 200, child: _buildEmptyState())
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: _filteredRecords.length,
                          itemBuilder: (context, index) {
                            final r = _filteredRecords[index];
                            final id = r['id'].toString();
                            final originalStock = r['stock'] ?? 0;
                            final tempStock = _editedStocks[id] ?? originalStock;
                            final isModified = tempStock != originalStock;

                            return _InventoryDailyCard(
                              record: r,
                              tempStock: tempStock,
                              isModified: isModified,
                              onIncrement: () {
                                setState(() {
                                  _editedStocks[id] = tempStock + 1;
                                });
                              },
                              onDecrement: () {
                                if (tempStock > 0) {
                                  setState(() {
                                    _editedStocks[id] = tempStock - 1;
                                  });
                                }
                              },
                              onSave: () => _saveStock(r, tempStock),
                              onAssign: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => _AssignStaffStockDialog(
                                    record: r,
                                    onSaved: _loadDailyInventory,
                                  ),
                                );
                              },
                            );
                          },
                        ),

              const Divider(height: 30, thickness: 1, indent: 20, endIndent: 20),

              // Sección de Último Pedido
              _buildLatestPedidoSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCalendar() {
    final monthYearStr = intl.DateFormat('MMMM yyyy', 'es').format(_selectedDate);
    final formattedMonthYear = monthYearStr[0].toUpperCase() + monthYearStr.substring(1);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 4),
            child: Row(
              children: [
                Text(
                  formattedMonthYear,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.black54),
                  onPressed: _selectDateDialog,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              controller: _dateScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                final isSelected = date.year == _selectedDate.year &&
                                   date.month == _selectedDate.month &&
                                   date.day == _selectedDate.day;
                
                final dayName = intl.DateFormat('E', 'es').format(date).toUpperCase();
                final dayNum = date.day.toString();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                    _loadDailyInventory();
                    _scrollToSelectedDate();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    width: 60,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayNum,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestPedidoSection() {
    if (_loadingPedido) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    if (_latestPedido == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2E)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined, color: Colors.white38, size: 40),
            SizedBox(height: 12),
            Text(
              'Sin pedidos registrados',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'No se encontró ningún pedido a proveedores.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final p = _latestPedido!;
    final providerName = p['proveedor'] ?? 'Desconocido';
    final rawDateStr = p['fecha'];
    final total = (p['precio_total_pedid'] ?? 0.0) as num;
    final debt = (p['deuda'] ?? 0.0) as num;
    final term = p['dias_credito'] as int? ?? 0;
    final msi = p['meses_sin_intereses'] as int? ?? 0;
    final method = p['metodos_pago'] as String? ?? 'No especificado';
    final completado = p['completado'] as bool? ?? false;
    final urlFactura = p['url_factura'] as String?;

    String formattedDate = '';
    if (rawDateStr != null) {
      try {
        final parsedDate = DateTime.parse(rawDateStr);
        formattedDate = intl.DateFormat('d \'de\' MMM, yyyy', 'es').format(parsedDate);
      } catch (_) {
        formattedDate = rawDateStr.toString();
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white12,
                radius: 20,
                child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ÚLTIMO PEDIDO REGISTRADO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      providerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: completado
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  completado ? 'PAGADO' : 'PENDIENTE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: completado ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildPedidoInfoRow(
                        Icons.monetization_on_outlined,
                        'Total:',
                        '\$${total.toStringAsFixed(2)}',
                      ),
                    ),
                    Expanded(
                      child: _buildPedidoInfoRow(
                        Icons.money_off_csred_outlined,
                        'Deuda:',
                        '\$${debt.toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPedidoInfoRow(
                        Icons.calendar_today_outlined,
                        'Plazo:',
                        term > 0 ? '$term días' : 'Inmediato',
                      ),
                    ),
                    Expanded(
                      child: _buildPedidoInfoRow(
                        Icons.percent_outlined,
                        'MSI:',
                        msi > 0 ? '$msi MSI' : 'Sin MSI',
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.white10, height: 1, thickness: 0.5),
                ),
                _buildPedidoInfoRow(
                  Icons.payments_outlined,
                  'Método de pago:',
                  method,
                ),
                const SizedBox(height: 6),
                _buildPedidoInfoRow(
                  Icons.calendar_month_outlined,
                  'Fecha pedido:',
                  formattedDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (urlFactura != null && urlFactura.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(urlFactura);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.file_present_outlined, size: 16),
                  label: const Text(
                    'Ver Factura',
                    style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => PedidoFormDialog(
                      pedido: _latestPedido,
                      onSaved: () {
                        _fetchLatestPedido();
                      },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(
                  'Editar Pedido',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPedidoInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isToday = intl.DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              isToday ? 'No hay productos en el catálogo' : 'Sin inventario registrado',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isToday
                  ? 'Agrega productos a tu catálogo de inventario.'
                  : 'No se generó el inventario histórico para este día.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryDailyCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final int tempStock;
  final bool isModified;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onSave;
  final VoidCallback onAssign;

  const _InventoryDailyCard({
    required this.record,
    required this.tempStock,
    required this.isModified,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSave,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final name = record['nombre_producto'] ?? 'Sin Nombre';
    
    final productData = record['Productos'] as Map<String, dynamic>? ?? {};
    final category = productData['categoria'] ?? 'General';
    final imageUrl = productData['imagen_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: (imageUrl != null && imageUrl.toString().isNotEmpty)
                ? Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 14),
          // Name and category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Controles de stock: [ assign ] [ - ] [ tempStock ] [ + ] [ Guardar ]
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.assignment_ind_outlined, color: Colors.black54, size: 20),
                onPressed: onAssign,
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline, color: Colors.black54, size: 22),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$tempStock',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline, color: Colors.black54, size: 22),
              ),
              const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isModified ? Colors.black : Colors.grey[200],
                    foregroundColor: isModified ? Colors.white : Colors.black38,
                    elevation: isModified ? 1 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: isModified ? onSave : null,
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 50,
        height: 50,
        color: Colors.grey[200],
        child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.black26),
      );
}

// Painter para la gráfica de línea
class _InventoryLineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final TextDirection textDirection;

  _InventoryLineChartPainter(
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

    // Gradient fill under the line
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

    // Principal line
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

    // Dots at each day
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

    // Date labels
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

// ─── Dialog: Assign Stock to Staff ──────────────────────────────────────────

class _AssignStaffStockDialog extends StatefulWidget {
  final Map<String, dynamic> record;
  final VoidCallback onSaved;

  const _AssignStaffStockDialog({
    required this.record,
    required this.onSaved,
  });

  @override
  State<_AssignStaffStockDialog> createState() => _AssignStaffStockDialogState();
}

class _AssignStaffStockDialogState extends State<_AssignStaffStockDialog> {
  final _supabase = Supabase.instance.client;
  int _qtyToAssign = 1;

  List<Map<String, dynamic>> _staffList = [];
  Map<String, dynamic>? _selectedStaff;
  
  List<Map<String, dynamic>> _assignments = [];
  bool _loadingStaff = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchStaffList();
    _loadExistingAssignments();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadExistingAssignments() {
    final rawAsignaciones = widget.record['asignacion_personal'];
    if (rawAsignaciones is List) {
      _assignments = List<Map<String, dynamic>>.from(
        rawAsignaciones.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } else {
      _assignments = [];
    }
  }

  int _getRemainingStock() {
    final totalStock = widget.record['stock'] as int? ?? 0;
    final totalAssigned = _assignments.fold<int>(0, (sum, item) => sum + (item['cantidad'] as int? ?? 0));
    return totalStock - totalAssigned;
  }

  Future<void> _fetchStaffList() async {
    try {
      final response = await _supabase
          .from('Personal')
          .select('userID, nombre')
          .order('nombre', ascending: true);

      if (mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(response);
          _loadingStaff = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff list: $e');
      if (mounted) {
        setState(() => _loadingStaff = false);
      }
    }
  }

  void _addAssignment() {
    if (_selectedStaff == null) {
      _showSnackbar('Selecciona un miembro del personal.');
      return;
    }
    final qty = _qtyToAssign;
    if (qty <= 0) {
      _showSnackbar('Ingresa una cantidad válida mayor a 0.');
      return;
    }

    final personalId = _selectedStaff!['userID'].toString();
    final nombre = _selectedStaff!['nombre'].toString();

    setState(() {
      final existingIndex = _assignments.indexWhere((a) => a['personal_id'] == personalId);
      if (existingIndex != -1) {
        _assignments[existingIndex]['cantidad'] = qty;
      } else {
        _assignments.add({
          'personal_id': personalId,
          'nombre': nombre,
          'cantidad': qty,
        });
      }
      _selectedStaff = null;
      _qtyToAssign = 1;
    });
  }

  Future<void> _saveAssignments() async {
    setState(() => _isSaving = true);
    try {
      await _supabase
          .from('InventarioDiario')
          .update({'asignacion_personal': _assignments})
          .eq('id', widget.record['id']);

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asignación de stock guardada con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showSnackbar('Error al guardar asignación: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.record['nombre_producto'] ?? 'Producto';
    final totalStock = widget.record['stock'] as int? ?? 0;
    final totalAssigned = _assignments.fold<int>(0, (sum, item) => sum + (item['cantidad'] as int? ?? 0));
    final remainingStock = totalStock - totalAssigned;

    final selectedStaffId = _selectedStaff?['userID']?.toString();
    int currentStaffAssigned = 0;
    if (selectedStaffId != null) {
      for (final a in _assignments) {
        if (a['personal_id'].toString() == selectedStaffId) {
          currentStaffAssigned = a['cantidad'] as int? ?? 0;
          break;
        }
      }
    }
    final maxAllowed = remainingStock + currentStaffAssigned;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loadingStaff
              ? const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator(color: Colors.black)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_ind_outlined, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Asignar Stock: $productName',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text('Seleccionar Personal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          hint: const Text('Selecciona personal'),
                          value: _selectedStaff,
                          isExpanded: true,
                          items: _staffList.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s['nombre'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedStaff = val;
                              if (val != null) {
                                final staffId = val['userID'].toString();
                                final existingIndex = _assignments.indexWhere((a) => a['personal_id'].toString() == staffId);
                                if (existingIndex != -1) {
                                  _qtyToAssign = _assignments[existingIndex]['cantidad'] as int? ?? 1;
                                } else {
                                  _qtyToAssign = _getRemainingStock() > 0 ? 1 : 0;
                                }
                              } else {
                                _qtyToAssign = 1;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stock remaining status card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stock Restante en Almacén',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Disponible: $remainingStock de $totalStock unidades',
                                style: TextStyle(fontSize: 13, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$remainingStock',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Counter and Add button Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Decrement button
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _qtyToAssign > 1 ? const Color(0xFFF2F2F7) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.remove, color: _qtyToAssign > 1 ? Colors.black87 : Colors.black26),
                                    onPressed: _qtyToAssign > 1
                                        ? () {
                                            setState(() => _qtyToAssign--);
                                          }
                                        : null,
                                  ),
                                ),
                                // Quantity display
                                Column(
                                  children: [
                                    const Text(
                                      'CANTIDAD',
                                      style: TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$_qtyToAssign',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                  ],
                                ),
                                // Increment button
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _qtyToAssign < maxAllowed ? const Color(0xFFF2F2F7) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.add, color: _qtyToAssign < maxAllowed ? Colors.black87 : Colors.black26),
                                    onPressed: _qtyToAssign < maxAllowed
                                        ? () {
                                            setState(() => _qtyToAssign++);
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            minimumSize: const Size(110, 52),
                          ),
                          onPressed: (_selectedStaff != null && _qtyToAssign <= maxAllowed && maxAllowed > 0)
                              ? _addAssignment
                              : null,
                          child: const Text('Agregar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text('Asignaciones Actuales:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black38)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: _assignments.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                  child: Text('No hay asignaciones para este día.', style: TextStyle(color: Colors.black38, fontSize: 12))),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _assignments.length,
                              itemBuilder: (context, index) {
                                final a = _assignments[index];
                                final name = a['nombre'] ?? '';
                                final qty = a['cantidad'] ?? 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(Icons.remove, size: 16, color: qty > 1 ? Colors.black87 : Colors.black26),
                                        onPressed: qty > 1
                                            ? () {
                                                setState(() {
                                                  a['cantidad'] = qty - 1;
                                                  if (_selectedStaff != null && _selectedStaff!['userID'].toString() == a['personal_id'].toString()) {
                                                    _qtyToAssign = qty - 1;
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                      Text(
                                        '$qty',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(Icons.add, size: 16, color: remainingStock > 0 ? Colors.black87 : Colors.black26),
                                        onPressed: remainingStock > 0
                                            ? () {
                                                setState(() {
                                                  a['cantidad'] = qty + 1;
                                                  if (_selectedStaff != null && _selectedStaff!['userID'].toString() == a['personal_id'].toString()) {
                                                    _qtyToAssign = qty + 1;
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _assignments.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black26),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveAssignments,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
