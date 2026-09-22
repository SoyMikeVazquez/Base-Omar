import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/custom_text_field.dart';

class ProveedoresStockScreen extends StatefulWidget {
  const ProveedoresStockScreen({super.key});

  @override
  State<ProveedoresStockScreen> createState() => _ProveedoresStockScreenState();
}

class _ProveedoresStockScreenState extends State<ProveedoresStockScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Tab control
  late TabController _tabController;

  // Tab 1: Supplier Orders (Pedidos)
  List<Map<String, dynamic>> _pedidos = [];
  final TextEditingController _searchPedidoCtrl = TextEditingController();
  String _pedidoSearchQuery = '';

  // Tab 2: Suppliers Directory
  List<Map<String, dynamic>> _suppliers = [];
  Map<String, String> _productNames = {}; // maps productId -> productName
  final TextEditingController _searchSupplierCtrl = TextEditingController();
  String _supplierSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Rebuild FAB when changing tabs
      if (mounted) setState(() {});
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchPedidoCtrl.dispose();
    _searchSupplierCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await _fetchSuppliersAndProducts();
    await _fetchPedidos();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchSuppliersAndProducts() async {
    try {
      // 1. Fetch suppliers
      final supResp = await _supabase
          .from('Proveedores')
          .select()
          .order('nombre', ascending: true);

      // 2. Fetch all products to map product IDs to names, categories, and images
      final prodResp = await _supabase
          .from('Productos')
          .select('id, nombre, categoria, imagen_url');

      final suppliers = List<Map<String, dynamic>>.from(supResp);
      final products = List<Map<String, dynamic>>.from(prodResp);

      Map<String, String> namesMap = {};
      for (final p in products) {
        final idStr = p['id'].toString();
        namesMap[idStr] = p['nombre'] ?? '';
      }

      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _productNames = namesMap;
        });
      }
    } catch (e) {
      debugPrint('Error loading suppliers and products: $e');
    }
  }

  Future<void> _fetchPedidos() async {
    try {
      final response = await _supabase
          .from('ProveedoresStock')
          .select()
          .order('fecha', ascending: false);

      final list = List<Map<String, dynamic>>.from(response);
      
      // Filter list to only keep rows containing products in JSONB format
      final orders = list.where((order) {
        final raw = order['productos_pedidos'];
        if (raw is List && raw.isNotEmpty) return true;
        if (raw is String) {
          try {
            final decoded = jsonDecode(raw);
            return decoded is List && decoded.isNotEmpty;
          } catch (_) {}
        }
        return false;
      }).toList();

      if (mounted) {
        setState(() {
          _pedidos = orders;
        });
      }
    } catch (e) {
      debugPrint('Error loading Pedidos: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredPedidos {
    if (_pedidoSearchQuery.trim().isEmpty) {
      return _pedidos;
    }
    final query = _pedidoSearchQuery.toLowerCase();
    return _pedidos.where((p) {
      final provider = (p['proveedor'] ?? '').toString().toLowerCase();
      final method = (p['metodos_pago'] ?? '').toString().toLowerCase();
      return provider.contains(query) || method.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSuppliers {
    if (_supplierSearchQuery.trim().isEmpty) {
      return _suppliers;
    }
    final query = _supplierSearchQuery.toLowerCase();
    return _suppliers.where((s) {
      final name = (s['nombre'] ?? '').toString().toLowerCase();
      final contact = (s['contacto'] ?? '').toString().toLowerCase();
      return name.contains(query) || contact.contains(query);
    }).toList();
  }

  void _openSupplierDialog([Map<String, dynamic>? supplier]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SupplierFormDialog(
        supplier: supplier,
        onSaved: _loadAllData,
      ),
    );
  }

  void _openPedidoDialog([Map<String, dynamic>? pedido]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PedidoFormDialog(
        pedido: pedido,
        onSaved: () {
          _loadAllData();
        },
      ),
    );
  }

  Future<void> _deletePedido(String id, String providerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Pedido'),
        content: Text('¿Estás seguro de que deseas eliminar el pedido de "$providerName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('ProveedoresStock').delete().eq('id', id);
      _loadAllData();
      _showSuccessSnackbar('Pedido eliminado con éxito.');
    } catch (e) {
      _showErrorSnackbar('Error al eliminar pedido: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSupplier(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Proveedor'),
        content: Text('¿Estás seguro de que deseas eliminar a "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('Proveedores').delete().eq('id', id);
      _loadAllData();
      _showSuccessSnackbar('Proveedor eliminado con éxito.');
    } catch (e) {
      _showErrorSnackbar('Error al eliminar proveedor: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Stock y Proveedores',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Pedidos'),
            Tab(text: 'Directorio'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Pedidos History
            Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: CustomTextField(
                    controller: _searchPedidoCtrl,
                    label: 'Buscar pedido por proveedor...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (val) {
                      setState(() => _pedidoSearchQuery = val);
                    },
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.black))
                      : _filteredPedidos.isEmpty
                          ? _buildEmptyStateForPedidos()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              itemCount: _filteredPedidos.length,
                              itemBuilder: (context, index) {
                                final pedido = _filteredPedidos[index];
                                return _PedidoCard(
                                  pedido: pedido,
                                  onEdit: () => _openPedidoDialog(pedido),
                                  onDelete: () => _deletePedido(pedido['id'], pedido['proveedor']),
                                );
                              },
                            ),
                ),
              ],
            ),

            // Tab 2: Directory of Suppliers
            Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: CustomTextField(
                    controller: _searchSupplierCtrl,
                    label: 'Buscar proveedor...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (val) {
                      setState(() => _supplierSearchQuery = val);
                    },
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.black))
                      : _filteredSuppliers.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              itemCount: _filteredSuppliers.length,
                              itemBuilder: (context, index) {
                                final supplier = _filteredSuppliers[index];
                                return _SupplierCard(
                                  supplier: supplier,
                                  productNames: _productNames,
                                  onEdit: () => _openSupplierDialog(supplier),
                                  onDelete: () => _deleteSupplier(supplier['id'], supplier['nombre']),
                                );
                              },
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              key: const ValueKey('fab_pedidos'),
              onPressed: () => _openPedidoDialog(),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.receipt_long_rounded, size: 20),
              label: const Text('Registrar Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : FloatingActionButton.extended(
              key: const ValueKey('fab_proveedores'),
              onPressed: () => _openSupplierDialog(),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              label: const Text('Nuevo Proveedor', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contact_page_outlined,
              size: 48,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            const Text(
              'Directorio vacío',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _supplierSearchQuery.isNotEmpty ? 'Sin resultados para la búsqueda.' : 'Agrega tus proveedores al directorio y asóciales sus productos.',
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

  Widget _buildEmptyStateForPedidos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin registros de pedidos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _pedidoSearchQuery.isNotEmpty ? 'Sin resultados para la búsqueda.' : 'Lleva el registro y control de tus facturas y pedidos por volumen.',
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

// ─── Supplier Card Widget ────────────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final Map<String, dynamic> supplier;
  final Map<String, String> productNames;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.productNames,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = supplier['nombre'] ?? 'Sin Nombre';
    final contact = supplier['contacto'] ?? 'Sin contacto';
    final category = supplier['categoria'] ?? 'General';
    final payment = supplier['metodos_pago'] as String? ?? '';
    final creditDays = supplier['dias_credito'] as int? ?? 0;
    final lapsoDays = supplier['lapso_pedido_dias'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF2F2F7),
                radius: 20,
                child: Icon(Icons.local_shipping_outlined, color: Colors.black87, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, color: Colors.black87, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          
          // Purchase details table/rows
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInfoRow(Icons.calendar_today_outlined, 'Frecuencia:', lapsoDays > 0 ? 'Cada $lapsoDays días' : 'No especificada')),
                    Expanded(child: _buildInfoRow(Icons.credit_card_outlined, 'Crédito:', creditDays > 0 ? '$creditDays días' : 'Sin crédito')),
                  ],
                ),
                if (payment.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, thickness: 0.5),
                  ),
                  _buildInfoRow(Icons.payments_outlined, 'Métodos de pago:', payment),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog: Supplier Form ───────────────────────────────────────────────────

class _SupplierFormDialog extends StatefulWidget {
  final Map<String, dynamic>? supplier;
  final VoidCallback onSaved;

  const _SupplierFormDialog({this.supplier, required this.onSaved});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();

  // New controllers
  String? _selectedCategory;
  final _paymentMethodsCtrl = TextEditingController();
  final _creditDaysCtrl = TextEditingController();
  final _periodicityCtrl = TextEditingController();

  bool _isSaving = false;

  static const List<String> _categories = [
    'Tintes & Decolorantes',
    'Shampoos & Acondicionadores',
    'Tratamientos Capilares',
    'Productos de Peinado (Ceras, Geles)',
    'Barbería (Aceites, Bálsamos)',
    'Herramientas (Tijeras, Máquinas, Secadores)',
    'Cosméticos & Maquillaje',
    'Cuidado de la Piel & Faciales',
    'Desechables & Artículos de Higiene',
    'Mobiliario & Equipamiento de Salón',
    'Otros',
  ];

  static const List<String> _paymentMethodsOptions = [
    'Efectivo',
    'Transferencia',
    'Tarjeta',
    'Crédito Proveedor',
    'Cheque',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    if (s != null) {
      _nameCtrl.text = s['nombre'] ?? '';
      _supplierCtrl.text = s['contacto'] ?? '';
      _selectedCategory = s['categoria'];
      _paymentMethodsCtrl.text = s['metodos_pago'] ?? '';
      _creditDaysCtrl.text = (s['dias_credito'] != null && s['dias_credito'] > 0) ? s['dias_credito'].toString() : '';
      _periodicityCtrl.text = (s['lapso_pedido_dias'] != null && s['lapso_pedido_dias'] > 0) ? s['lapso_pedido_dias'].toString() : '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _supplierCtrl.dispose();
    _paymentMethodsCtrl.dispose();
    _creditDaysCtrl.dispose();
    _periodicityCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnackbar('Por favor, ingresa el nombre del proveedor.');
      return;
    }
    final contact = _supplierCtrl.text.trim();

    setState(() => _isSaving = true);

    try {
      final isNew = widget.supplier == null;
      final data = {
        'nombre': name,
        'contacto': contact,
        'categoria': _selectedCategory,
        'metodos_pago': _paymentMethodsCtrl.text.trim(),
        'dias_credito': int.tryParse(_creditDaysCtrl.text) ?? 0,
        'lapso_pedido_dias': int.tryParse(_periodicityCtrl.text) ?? 0,
      };

      if (isNew) {
        await _supabase.from('Proveedores').insert(data);
      } else {
        await _supabase
            .from('Proveedores')
            .update(data)
            .eq('id', widget.supplier!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        _showSuccessSnackbar('Proveedor guardado con éxito.');
      }
    } catch (e) {
      _showSnackbar('Error al guardar proveedor: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.supplier == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.contact_page_outlined, size: 22),
                    const SizedBox(width: 8),
                    Text(isNew ? 'Nuevo Proveedor' : 'Editar Proveedor', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  controller: _nameCtrl,
                  label: 'Nombre del Proveedor',
                  prefixIcon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _supplierCtrl,
                  label: 'Contacto (Tel / Email / Dirección)',
                  prefixIcon: Icons.contact_phone_outlined,
                ),
                const SizedBox(height: 12),

                // Dropdown for Category with matching custom decoration
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: Colors.white,
                    decoration: const InputDecoration(
                      labelText: 'Clasificación por categoría',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategory = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                CustomTextField(
                  controller: _paymentMethodsCtrl,
                  label: 'Métodos de pago aceptados',
                  prefixIcon: Icons.payments_outlined,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _paymentMethodsOptions.map((opt) {
                      final isSelected = _paymentMethodsCtrl.text.contains(opt);
                      return ChoiceChip(
                        label: Text(opt, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                        selected: isSelected,
                        selectedColor: Colors.black.withOpacity(0.08),
                        backgroundColor: Colors.black.withOpacity(0.02),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isSelected ? Colors.black38 : Colors.transparent),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            List<String> current = _paymentMethodsCtrl.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            if (selected) {
                              if (!current.contains(opt)) current.add(opt);
                            } else {
                              current.remove(opt);
                            }
                            _paymentMethodsCtrl.text = current.join(', ');
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _creditDaysCtrl,
                        label: 'Días de crédito',
                        prefixIcon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _periodicityCtrl,
                        label: 'Frecuencia (días)',
                        prefixIcon: Icons.repeat_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Actions
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
                        onPressed: _isSaving ? null : _saveSupplier,
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
                            : const Text('Guardar', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pedido Card Widget ──────────────────────────────────────────────────────

class _PedidoCard extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PedidoCard({
    required this.pedido,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerName = pedido['nombre_proveedor'] ?? 'Desconocido';
    final rawDateStr = pedido['fecha_pedido'];
    final total = (pedido['total_pagar'] ?? 0.0) as num;
    final debt = (pedido['deuda'] ?? 0.0) as num;
    final term = pedido['plazo_pago'] as int? ?? 0;
    final msi = pedido['meses_sin_intereses'] as int? ?? 0;
    final method = pedido['metodo_pago'] as String? ?? 'No especificado';
    final completado = pedido['completado'] as bool? ?? false;
    final urlFactura = pedido['url_factura'] as String?;

    final rawProds = pedido['productos_pedidos'];
    List<Map<String, dynamic>> products = [];
    if (rawProds is List) {
      products = List<Map<String, dynamic>>.from(rawProds);
    } else if (rawProds is String) {
      try {
        products = List<Map<String, dynamic>>.from(jsonDecode(rawProds));
      } catch (_) {}
    }

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
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF2F2F7),
                radius: 20,
                child: Icon(Icons.receipt_long_rounded, color: Colors.black87, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: completado 
                      ? Colors.green.withValues(alpha: 0.08) 
                      : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  completado ? 'PAGADO' : 'PENDIENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: completado ? Colors.green : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),

          if (products.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 13, color: Colors.black54),
                      const SizedBox(width: 6),
                      const Text(
                        'Productos Solicitados',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, thickness: 0.5),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = products[index];
                      final name = item['nombre'] ?? 'Producto';
                      final qty = item['cantidad'] ?? 0;
                      final price = (item['precio_unitario'] ?? 0.0) as num;
                      final subtotal = qty * price;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$name  x$qty',
                              style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '\$${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInfoRow(Icons.monetization_on_outlined, 'Total:', '\$${total.toStringAsFixed(2)}')),
                    Expanded(child: _buildInfoRow(Icons.money_off_csred_outlined, 'Deuda:', '\$${debt.toStringAsFixed(2)}')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow(Icons.calendar_today_outlined, 'Plazo Crédito:', term > 0 ? '$term días' : 'Inmediato')),
                    Expanded(child: _buildInfoRow(Icons.percent_outlined, 'Financiamiento:', msi > 0 ? '$msi MSI' : 'Sin MSI')),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                _buildInfoRow(Icons.payments_outlined, 'Método de pago:', method),
              ],
            ),
          ),

          const SizedBox(height: 12),
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
                  icon: const Icon(Icons.file_present_outlined, size: 16, color: Colors.blue),
                  label: const Text('Ver Factura', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, color: Colors.black87, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Dialog: Pedido Form ─────────────────────────────────────────────────────

class PedidoFormDialog extends StatefulWidget {
  final Map<String, dynamic>? pedido;
  final VoidCallback onSaved;

  const PedidoFormDialog({super.key, this.pedido, required this.onSaved});

  @override
  State<PedidoFormDialog> createState() => _PedidoFormDialogState();
}

class _PedidoFormDialogState extends State<PedidoFormDialog> {
  final _supabase = Supabase.instance.client;
  final _totalCtrl = TextEditingController();
  final _plazoCtrl = TextEditingController();
  final _deudaCtrl = TextEditingController();
  
  // Controllers for adding a product
  final _qtyToAddCtrl = TextEditingController();
  final _priceToAddCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _selectedSupplier;
  List<Map<String, dynamic>> _suppliersList = [];
  
  // List of all products to choose from
  List<Map<String, dynamic>> _allProducts = [];
  Map<String, dynamic>? _selectedProductToAdd;

  // Selected products for this order
  List<Map<String, dynamic>> _orderProducts = [];

  String? _selectedMethod;
  int _msi = 0;
  bool _completado = false;
  bool _isLoadingSuppliers = true;
  bool _isLoadingProducts = true;
  bool _isSaving = false;

  String? _attachedFileName;
  File? _selectedFile;
  String? _existingUrlFactura;

  static const List<String> _paymentMethods = [
    'Efectivo',
    'Transferencia',
    'Tarjeta',
    'Crédito Proveedor',
    'Cheque',
  ];

  static const List<int> _msiOptions = [0, 3, 6, 9, 12, 18];

  @override
  void initState() {
    super.initState();
    _fetchSuppliersAndProducts();
    
    final p = widget.pedido;
    if (p != null) {
      _selectedDate = DateTime.tryParse(p['fecha'] ?? '') ?? DateTime.now();
      _totalCtrl.text = (p['precio_total_pedid'] ?? 0.0).toString();
      _plazoCtrl.text = (p['dias_credito'] ?? 0).toString();
      _deudaCtrl.text = (p['deuda'] ?? 0.0).toString();
      _selectedMethod = p['metodos_pago'];
      _msi = p['meses_sin_intereses'] as int? ?? 0;
      _completado = p['completado'] as bool? ?? false;
      _existingUrlFactura = p['url_factura'];
      if (_existingUrlFactura != null && _existingUrlFactura!.isNotEmpty) {
        _attachedFileName = 'Factura cargada';
      }
      
      // Load products list from jsonb column
      final rawProds = p['productos_pedidos'];
      if (rawProds is List) {
        _orderProducts = List<Map<String, dynamic>>.from(rawProds);
      } else if (rawProds is String) {
        try {
          _orderProducts = List<Map<String, dynamic>>.from(jsonDecode(rawProds));
        } catch (_) {}
      }
    }

    _totalCtrl.addListener(() {
      if (widget.pedido == null && !_completado) {
        _deudaCtrl.text = _totalCtrl.text;
      }
    });
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _plazoCtrl.dispose();
    _deudaCtrl.dispose();
    _qtyToAddCtrl.dispose();
    _priceToAddCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliersAndProducts() async {
    try {
      // 1. Fetch suppliers
      final supResp = await _supabase.from('Proveedores').select().order('nombre');
      // 2. Fetch products
      final prodResp = await _supabase.from('Productos').select('id, nombre, stock').order('nombre');
      
      setState(() {
        _suppliersList = List<Map<String, dynamic>>.from(supResp);
        _allProducts = List<Map<String, dynamic>>.from(prodResp);
        _isLoadingSuppliers = false;
        _isLoadingProducts = false;

        if (widget.pedido != null) {
          final pName = widget.pedido!['proveedor'];
          if (pName != null) {
            _selectedSupplier = _suppliersList.firstWhere(
              (s) => s['nombre'].toString() == pName.toString(),
              orElse: () => <String, dynamic>{},
            );
            if (_selectedSupplier?.isEmpty ?? true) _selectedSupplier = null;
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching suppliers and products: $e');
      setState(() {
        _isLoadingSuppliers = false;
        _isLoadingProducts = false;
      });
    }
  }

  void _recalculateTotal() {
    double total = 0.0;
    for (final item in _orderProducts) {
      total += (item['cantidad'] as int) * (item['precio_unitario'] as double);
    }
    setState(() {
      _totalCtrl.text = total.toStringAsFixed(2);
      if (!_completado) {
        _deudaCtrl.text = total.toStringAsFixed(2);
      }
    });
  }

  void _addProduct() {
    if (_selectedProductToAdd == null) {
      _showSnackbar('Por favor, selecciona un producto.');
      return;
    }
    final qty = int.tryParse(_qtyToAddCtrl.text.trim());
    if (qty == null || qty <= 0) {
      _showSnackbar('Ingresa una cantidad válida mayor a 0.');
      return;
    }
    final price = double.tryParse(_priceToAddCtrl.text.trim());
    if (price == null || price < 0) {
      _showSnackbar('Ingresa un precio válido (mayor o igual a 0).');
      return;
    }

    setState(() {
      final existingIndex = _orderProducts.indexWhere((p) => p['id'] == _selectedProductToAdd!['id']);
      if (existingIndex != -1) {
        _orderProducts[existingIndex]['cantidad'] += qty;
        _orderProducts[existingIndex]['precio_unitario'] = price;
      } else {
        _orderProducts.add({
          'id': _selectedProductToAdd!['id'],
          'nombre': _selectedProductToAdd!['nombre'],
          'cantidad': qty,
          'precio_unitario': price,
        });
      }
      _selectedProductToAdd = null;
      _qtyToAddCtrl.clear();
      _priceToAddCtrl.clear();
    });
    _recalculateTotal();
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _attachedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<String?> _uploadFile() async {
    if (_selectedFile == null) return _existingUrlFactura;

    final fileName = 'facturas_pedidos/${DateTime.now().millisecondsSinceEpoch}_${_attachedFileName}';
    final bytes = await _selectedFile!.readAsBytes();

    await _supabase.storage.from('general').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final publicUrl = _supabase.storage.from('general').getPublicUrl(fileName);
    return publicUrl;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _savePedido() async {
    if (_selectedSupplier == null && widget.pedido == null) {
      _showSnackbar('Por favor, selecciona un proveedor.');
      return;
    }
    if (_orderProducts.isEmpty) {
      _showSnackbar('Debes agregar al menos un producto al pedido.');
      return;
    }
    final total = double.tryParse(_totalCtrl.text) ?? 0.0;
    if (total <= 0) {
      _showSnackbar('Por favor, ingresa un total válido mayor a 0.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String? invoiceUrl = await _uploadFile();
      final isNew = widget.pedido == null;

      final data = {
        'fecha': intl.DateFormat('yyyy-MM-dd').format(_selectedDate),
        'precio_total_pedid': total,
        'dias_credito': int.tryParse(_plazoCtrl.text) ?? 0,
        'deuda': _completado ? 0.0 : (double.tryParse(_deudaCtrl.text) ?? 0.0),
        'metodos_pago': _selectedMethod,
        'meses_sin_intereses': _msi,
        'completado': _completado,
        'url_factura': invoiceUrl,
        'productos_pedidos': _orderProducts,
      };

      if (isNew) {
        data['proveedor'] = _selectedSupplier!['nombre'];
        
        // 1. Insert order into ProveedoresStock
        await _supabase.from('ProveedoresStock').insert(data);
        
        // 2. Increment stock in Productos for each product
        final futures = <Future>[];
        for (final item in _orderProducts) {
          final productId = item['id'];
          final qty = item['cantidad'] as int;
          
          futures.add(
            () async {
              final prodData = await _supabase.from('Productos').select('stock').eq('id', productId).maybeSingle();
              final currentStock = prodData?['stock'] ?? 0;
              await _supabase.from('Productos').update({
                'stock': currentStock + qty,
              }).eq('id', productId);
            }()
          );
        }
        await Future.wait(futures);
      } else {
        if (_selectedSupplier != null) {
          data['proveedor'] = _selectedSupplier!['nombre'];
        }
        await _supabase
            .from('ProveedoresStock')
            .update(data)
            .eq('id', widget.pedido!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        _showSuccessSnackbar('Pedido guardado con éxito.');
      }
    } catch (e) {
      _showSnackbar('Error al guardar pedido: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String msg) {
    if (mounted) {
      FocusScope.of(context).unfocus();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Validación', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(msg, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Widget _buildAddedProductsList() {
    if (_orderProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Ningún producto agregado al pedido aún.',
          style: TextStyle(color: Colors.black38, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Column(
      children: _orderProducts.map((item) {
        final subtotal = (item['cantidad'] as int) * (item['precio_unitario'] as double);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: const Color(0xFFF2F2F7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            title: Text(item['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${item['cantidad']} uds x \$${(item['precio_unitario'] as double).toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () {
                    setState(() {
                      _orderProducts.removeWhere((p) => p['id'] == item['id']);
                    });
                    _recalculateTotal();
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.pedido == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: (_isLoadingSuppliers || _isLoadingProducts)
              ? const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator(color: Colors.black)),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 22),
                          const SizedBox(width: 8),
                          Text(isNew ? 'Nuevo Pedido' : 'Editar Pedido', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (isNew) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<Map<String, dynamic>>(
                            value: _selectedSupplier,
                            dropdownColor: Colors.white,
                            decoration: const InputDecoration(
                              labelText: 'Proveedor',
                              prefixIcon: Icon(Icons.person_outline),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            items: _suppliersList.map((s) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: s,
                                child: Text(s['nombre'] ?? '', style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedSupplier = val);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Text(
                          'Proveedor: ${widget.pedido!['nombre_proveedor']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                      ],

                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.black54),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Fecha del Pedido', style: TextStyle(fontSize: 10, color: Colors.black45)),
                                    const SizedBox(height: 2),
                                    Text(intl.DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.black45),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- PRODUCT SELECTION SECTION ---
                      const Text(
                        'Agregar Productos al Pedido',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedProductToAdd,
                          dropdownColor: Colors.white,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Producto',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          items: _allProducts.map((p) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: p,
                              child: Text(p['nombre'] ?? '', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedProductToAdd = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _qtyToAddCtrl,
                              label: 'Cantidad',
                              prefixIcon: Icons.add,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _priceToAddCtrl,
                              label: 'Precio Unitario (\$)',
                              prefixIcon: Icons.attach_money_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _addProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar Producto', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Productos agregados:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      _buildAddedProductsList(),
                      const Divider(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _totalCtrl,
                              label: 'Total a Pagar (\$)',
                              prefixIcon: Icons.attach_money_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _plazoCtrl,
                              label: 'Plazo (Días crédito)',
                              prefixIcon: Icons.calendar_today_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _deudaCtrl,
                              label: 'Deuda Restante (\$)',
                              prefixIcon: Icons.money_off_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              suffixIcon: _completado ? const Icon(Icons.lock_outline, size: 16) : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Text('Pagado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Switch(
                                  value: _completado,
                                  activeColor: Colors.green,
                                  onChanged: (val) {
                                    setState(() {
                                      _completado = val;
                                      if (_completado) {
                                        _deudaCtrl.text = '0.0';
                                      } else {
                                        _deudaCtrl.text = _totalCtrl.text;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedMethod,
                          dropdownColor: Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Método de Pago',
                            prefixIcon: Icon(Icons.payments_outlined),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          items: _paymentMethods.map((m) {
                            return DropdownMenuItem<String>(
                              value: m,
                              child: Text(m, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedMethod = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<int>(
                          value: _msi,
                          dropdownColor: Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Meses sin Intereses (MSI)',
                            prefixIcon: Icon(Icons.percent_outlined),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          items: _msiOptions.map((opt) {
                            return DropdownMenuItem<int>(
                              value: opt,
                              child: Text(opt == 0 ? 'Sin MSI (0)' : '$opt Meses', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _msi = val ?? 0);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Factura o Comprobante (PDF / Foto)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _attachedFileName ?? 'Ningún archivo adjuntado',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _attachedFileName != null ? Colors.black87 : Colors.black38,
                                      fontStyle: _attachedFileName != null ? FontStyle.normal : FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _pickAttachment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.attach_file_rounded, size: 14),
                                  label: const Text('Adjuntar', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
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
                              onPressed: _isSaving ? null : _savePedido,
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
                                  : const Text('Guardar', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
