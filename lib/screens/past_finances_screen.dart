import 'package:flutter/material.dart';
import 'package:totalpro/utils/formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;

class PastFinancesScreen extends StatefulWidget {
  const PastFinancesScreen({super.key});

  @override
  State<PastFinancesScreen> createState() => _PastFinancesScreenState();
}

class _PastFinancesScreenState extends State<PastFinancesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];

  // Filter states
  String _searchQuery = '';
  String _selectedSucursal = 'Todas';
  String _selectedPersonal = 'Todos';
  String _selectedType = 'Todos'; // 'Todos', 'Servicios', 'Productos'

  List<String> _sucursalesList = ['Todas'];
  List<String> _personalList = ['Todos'];

  @override
  void initState() {
    super.initState();
    _fetchFinances();
  }

  Future<void> _fetchFinances() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('FinanzasEnTiempoReal')
          .select()
          .eq('IDEmpresa', 'FRFROIJNU821')
          .order('Creacion', ascending: false);

      final data = List<Map<String, dynamic>>.from(response);

      // Extract unique branches and staff for dropdown filters
      final uniqueSucursales = <String>{};
      final uniquePersonal = <String>{};

      for (var row in data) {
        final suc = row['Sucursal']?.toString().trim();
        if (suc != null && suc.isNotEmpty) {
          uniqueSucursales.add(suc);
        }
        final pers = row['Personal']?.toString().trim();
        if (pers != null && pers.isNotEmpty) {
          uniquePersonal.add(pers);
        }
      }

      if (mounted) {
        setState(() {
          _allTransactions = data;
          _sucursalesList = ['Todas', ...uniqueSucursales.toList()..sort()];
          _personalList = ['Todos', ...uniquePersonal.toList()..sort()];
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar las finanzas: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = _allTransactions;

    // Search query filter (matches Personal or Sucursal)
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      temp = temp.where((t) {
        final personal = (t['Personal'] ?? '').toString().toLowerCase();
        final sucursal = (t['Sucursal'] ?? '').toString().toLowerCase();
        final transaccion = (t['IDTransacción'] ?? '').toString().toLowerCase();
        return personal.contains(query) ||
            sucursal.contains(query) ||
            transaccion.contains(query);
      }).toList();
    }

    // Branch filter
    if (_selectedSucursal != 'Todas') {
      temp = temp.where((t) => t['Sucursal'] == _selectedSucursal).toList();
    }

    // Staff filter
    if (_selectedPersonal != 'Todos') {
      temp = temp.where((t) => t['Personal'] == _selectedPersonal).toList();
    }

    // Type filter (Servicios / Productos)
    if (_selectedType == 'Servicios') {
      temp = temp.where((t) => t['esProducto'] == false || t['esProducto'] == null).toList();
    } else if (_selectedType == 'Productos') {
      temp = temp.where((t) => t['esProducto'] == true).toList();
    }

    setState(() {
      _filteredTransactions = temp;
    });
  }

  // Summary calculation properties
  double get _totalIngresos {
    return _filteredTransactions.fold(0.0, (sum, t) {
      final monto = double.tryParse((t['Monto'] ?? 0).toString()) ?? 0.0;
      return sum + monto;
    });
  }

  double get _totalServicios {
    return _filteredTransactions
        .where((t) => t['esProducto'] == false || t['esProducto'] == null)
        .fold(0.0, (sum, t) {
      final monto = double.tryParse((t['Monto'] ?? 0).toString()) ?? 0.0;
      return sum + monto;
    });
  }

  double get _totalProductos {
    return _filteredTransactions
        .where((t) => t['esProducto'] == true)
        .fold(0.0, (sum, t) {
      final monto = double.tryParse((t['Monto'] ?? 0).toString()) ?? 0.0;
      return sum + monto;
    });
  }

  double get _cajaGlobal {
    double cashIncome = 0.0;
    double expenses = 0.0;
    for (var t in _filteredTransactions) {
      final isGasto = (t['Gasto'] != null && t['Gasto'].toString().trim().isNotEmpty) || (t['descripcion_extras'] == 'Gasto registrado');
      final monto = isGasto ? (double.tryParse(t['Gasto'].toString()) ?? 0.0) : (double.tryParse((t['total'] ?? 0).toString()) ?? 0.0);
      final formaPago = (t['formadepago'] as String? ?? '').toLowerCase().trim();
      
      if (isGasto) {
        expenses += monto;
      } else if (formaPago.contains('efectivo')) {
        cashIncome += monto;
      }
    }
    return cashIncome - expenses;
  }

  double get _cashIncomeGlobal {
    double cashIncome = 0.0;
    for (var t in _filteredTransactions) {
      final isGasto = (t['Gasto'] != null && t['Gasto'].toString().trim().isNotEmpty) || (t['descripcion_extras'] == 'Gasto registrado');
      final monto = double.tryParse((t['total'] ?? 0).toString()) ?? 0.0;
      final formaPago = (t['formadepago'] as String? ?? '').toLowerCase().trim();
      if (!isGasto && formaPago.contains('efectivo')) {
        cashIncome += monto;
      }
    }
    return cashIncome;
  }

  double get _expensesGlobal {
    double expenses = 0.0;
    for (var t in _filteredTransactions) {
      final isGasto = (t['Gasto'] != null && t['Gasto'].toString().trim().isNotEmpty) || (t['descripcion_extras'] == 'Gasto registrado');
      if (isGasto) {
        expenses += double.tryParse(t['Gasto'].toString()) ?? 0.0;
      }
    }
    return expenses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Finanzas Pasadas',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.black87), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchFinances,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                          child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchFinances,
                  color: Colors.black,
                  child: CustomScrollView(
                    slivers: [
                      // Header stats summary cards
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: _buildStatsSummaryRow(),
                        ),
                      ),

                      // Interactive Filters Box
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildFilterSection(),
                        ),
                      ),

                      // Transaction list section title
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Transacciones (${_filteredTransactions.length})',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              if (_searchQuery.isNotEmpty ||
                                  _selectedSucursal != 'Todas' ||
                                  _selectedPersonal != 'Todos' ||
                                  _selectedType != 'Todos')
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedSucursal = 'Todas';
                                      _selectedPersonal = 'Todos';
                                      _selectedType = 'Todos';
                                    });
                                    _applyFilters();
                                  },
                                  child: const Text('Limpiar filtros', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // List of transactions
                      _filteredTransactions.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final tx = _filteredTransactions[index];
                                    return _buildTransactionCard(tx);
                                  },
                                  childCount: _filteredTransactions.length,
                                ),
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsSummaryRow() {
    return Column(
      children: [
        // Total revenues card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F1F1F), Color(0xFF0D0D0D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('Ingresos Totales en Tiempo Real', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$_currencySymbol${formatMoney(_totalIngresos)}',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              const Text('Filtro activo: IDEmpresa = FRFROIJNU821', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Services and Products cards row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.spa_rounded, color: Colors.blueAccent, size: 14),
                        ),
                        const SizedBox(width: 6),
                        const Text('Servicios', style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$_currencySymbol${formatMoney(_totalServicios)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_rounded, color: Colors.amber, size: 14),
                        ),
                        const SizedBox(width: 6),
                        const Text('Productos', style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$_currencySymbol${formatMoney(_totalProductos)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Premium dark look
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                      color: Colors.white.withValues(alpha: 0.1),
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

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          TextField(
            onChanged: (val) {
              setState(() => _searchQuery = val);
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Buscar por personal, sucursal o transacción...',
              prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black54),
              isDense: true,
              hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black54)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
          ),
          const SizedBox(height: 12),

          // Dropdowns for Sucursal and Personal
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sucursal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSucursal,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                          items: _sucursalesList.map((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text(val, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSucursal = val);
                              _applyFilters();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Personal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPersonal,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                          items: _personalList.map((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text(val, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedPersonal = val);
                              _applyFilters();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toggles for Servicios / Productos
          const Text('Mostrar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 6),
          Row(
            children: ['Todos', 'Servicios', 'Productos'].map((type) {
              final isSelected = _selectedType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedType = type);
                      _applyFilters();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300),
                      ),
                      child: Text(
                        type,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final monto = double.tryParse((tx['Monto'] ?? 0).toString()) ?? 0.0;
    final isProd = tx['esProducto'] == true;
    final personal = tx['Personal']?.toString() ?? 'Sin registrar';
    final sucursal = tx['Sucursal']?.toString() ?? 'Sin sucursal';
    final formaPago = tx['FormaDePago']?.toString() ?? 'No especificado';
    final transaccion = tx['IDTransacción']?.toString();

    // Format date beautifully
    String dateStr = '';
    if (tx['Creacion'] != null) {
      try {
        final dt = DateTime.parse(tx['Creacion'].toString()).toLocal();
        dateStr = intl.DateFormat('dd/MM/yyyy - hh:mm a').format(dt);
      } catch (_) {
        dateStr = tx['Creacion'].toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon indicator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isProd ? Colors.amber : Colors.blue).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isProd ? Icons.shopping_bag_outlined : Icons.spa_outlined,
              color: isProd ? Colors.amber.shade700 : Colors.blueAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Detail columns
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Amount
                    Text(
                      '$_currencySymbol${formatMoney(monto)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    // Payment Method badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        formaPago,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 12, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      personal,
                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 12, color: Colors.black38),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sucursal,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (transaccion != null && transaccion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ID Transacción: $transaccion',
                    style: const TextStyle(fontSize: 9, color: Colors.black38, fontFamily: 'monospace'),
                  ),
                ],
                const SizedBox(height: 6),
                // Date
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(Icons.search_off_rounded, color: Colors.grey.shade400, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin transacciones',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            const Text(
              'No se encontraron registros de finanzas en tiempo real que coincidan con los filtros seleccionados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  static const String _currencySymbol = '\$';
}
