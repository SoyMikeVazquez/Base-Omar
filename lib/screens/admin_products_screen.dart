import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_text_field.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Productos')
          .select()
          .order('NombreProducto', ascending: true);
      setState(() => _products = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text('¿Estás seguro de que deseas eliminar este producto?'),
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
      await _supabase.from('Productos').delete().eq('id', id);
      _fetchProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _openForm([Map<String, dynamic>? product]) {
    showDialog(
      context: context,
      builder: (ctx) => _ProductFormDialog(
        product: product,
        onSaved: _fetchProducts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Administrar Productos',
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Catálogo de Productos',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openForm(),
                          icon: const Icon(Icons.add, color: Colors.white, size: 16),
                          label: const Text('Nuevo', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_products.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text(
                            'No hay productos registrados.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    else
                      ..._products.map((p) => _ProductCard(
                            product: p,
                            onEdit: () => _openForm(p),
                            onDelete: () => _deleteProduct(p['id']),
                          )),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['imagen_url'] ?? product['ImagenProducto'];
    final price = product['precio'] ?? product['montoProducto'];
    final stock = product['stock'] ?? product['cantidadInventario'];
    final category = product['categoria'] ?? product['Categoria'] ?? 'Sin Categoría';
    final supplier = product['contacto_proveedor'] ?? '';

    // Handle coupons list safe parsing
    List<dynamic> couponsRaw = [];
    if (product['cupones_aplicables'] is List) {
      couponsRaw = product['cupones_aplicables'] as List;
    }
    final coupons = couponsRaw.map((e) => e.toString()).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: (imageUrl != null && imageUrl.toString().isNotEmpty)
                ? Image.network(
                    imageUrl,
                    width: 110,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['nombre'] ?? product['NombreProducto'] ?? 'Sin Nombre',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['descripcion'] ?? product['DescripciónProducto'] ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (price != null)
                        _ProductChip(label: '\$$price', icon: Icons.attach_money),
                      if (stock != null)
                        _ProductChip(label: 'Stock: $stock', icon: Icons.inventory_2_outlined),
                      _ProductChip(label: category, icon: Icons.category_outlined),
                      _ProductChip(
                        label: (product['disponible_venta'] ?? true) ? 'Venta al público' : 'Insumo interno',
                        icon: Icons.info_outline,
                      ),
                      if ((product['porcentaje_venta_personal'] ?? 0) > 0)
                        _ProductChip(
                          label: 'Comisión: ${product['porcentaje_venta_personal']}%',
                          icon: Icons.percent_outlined,
                        ),
                    ],
                  ),
                  if (supplier.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Proveedor: $supplier',
                      style: const TextStyle(fontSize: 10, color: Colors.black54, fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (coupons.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Cupones: ${coupons.join(", ")}',
                      style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Actions
          Column(
            children: [
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.black87, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 110,
        height: 140,
        color: Colors.grey[200],
        child: const Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.black26),
      );
}

class _ProductChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ProductChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// ─── Form Dialog ────────────────────────────────────────────────────────────

class _ProductFormDialog extends StatefulWidget {
  final Map<String, dynamic>? product;
  final VoidCallback onSaved;

  const _ProductFormDialog({this.product, required this.onSaved});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _porcentajeVentaPersonalCtrl = TextEditingController();

  String _selectedCategory = 'Cabello';
  final List<String> _categories = ['Cabello', 'Barba', 'Facial', 'Cuidado', 'Cuerpo', 'Otros'];

  XFile? _mainImageFile;
  Uint8List? _mainImageBytes;
  String? _mainImageUrl;
  bool _isUploading = false;
  bool _disponibleVenta = true;

  List<Map<String, dynamic>> _allCoupons = [];
  List<String> _selectedCoupons = [];
  bool _loadingCoupons = true;

  @override
  void initState() {
    super.initState();
    _fetchCoupons();

    final p = widget.product;
    if (p != null) {
      _nameCtrl.text = p['nombre'] ?? p['NombreProducto'] ?? '';
      _descCtrl.text = p['descripcion'] ?? p['DescripciónProducto'] ?? '';
      _priceCtrl.text = (p['precio'] ?? p['montoProducto'] ?? '').toString();
      _stockCtrl.text = (p['stock'] ?? p['cantidadInventario'] ?? '').toString();
      _supplierCtrl.text = p['contacto_proveedor'] ?? '';
      _porcentajeVentaPersonalCtrl.text = (p['porcentaje_venta_personal'] ?? 0).toString();

      final cat = p['categoria'] ?? p['Categoria'] ?? 'Cabello';
      if (_categories.contains(cat)) {
        _selectedCategory = cat;
      } else {
        _selectedCategory = 'Otros';
      }

      _mainImageUrl = p['imagen_url'] ?? p['ImagenProducto'];
      _disponibleVenta = p['disponible_venta'] ?? p['isDisponibleVenta'] ?? true;

      if (p['cupones_aplicables'] is List) {
        final list = p['cupones_aplicables'] as List;
        _selectedCoupons = list.map((e) => e.toString()).toList();
      }
    }
  }

  Future<void> _fetchCoupons() async {
    try {
      final resp = await Supabase.instance.client
          .from('Cupones')
          .select('IDCupon')
          .order('IDCupon');
      if (mounted) {
        setState(() {
          _allCoupons = List<Map<String, dynamic>>.from(resp);
          _loadingCoupons = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCoupons = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _mainImageFile = file;
        _mainImageBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del producto es obligatorio.')),
      );
      return;
    }
    setState(() => _isUploading = true);

    try {
      final isNew = widget.product == null;
      final productId = isNew
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.product!['id'].toString();

      String? mainUrl = _mainImageUrl;
      if (_mainImageFile != null && _mainImageBytes != null) {
        mainUrl = await _uploadImage(_mainImageFile!, _mainImageBytes!, productId);
      }

      num? parseNum(String v) => v.trim().isEmpty ? null : num.tryParse(v.trim());
      int? parseInt(String v) => v.trim().isEmpty ? null : int.tryParse(v.trim());

      final idProductos = isNew
          ? DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()
          : widget.product!['IDProductos'] ?? '';

      final data = <String, dynamic>{
        // New columns
        'nombre': _nameCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
        'precio': parseNum(_priceCtrl.text),
        'stock': parseInt(_stockCtrl.text) ?? 0,
        'categoria': _selectedCategory,
        'contacto_proveedor': _supplierCtrl.text.trim(),
        'porcentaje_venta_personal': parseNum(_porcentajeVentaPersonalCtrl.text) ?? 0,
        'cupones_aplicables': _selectedCoupons,
        'disponible_venta': _disponibleVenta,
        'updated_at': DateTime.now().toIso8601String(),
        if (mainUrl != null) 'imagen_url': mainUrl,

        // Old columns (for database backward compatibility)
        'NombreProducto': _nameCtrl.text.trim(),
        'DescripciónProducto': _descCtrl.text.trim(),
        'montoProducto': parseNum(_priceCtrl.text),
        'cantidadInventario': parseInt(_stockCtrl.text) ?? 0,
        'Categoria': _selectedCategory,
        'isDisponibleVenta': _disponibleVenta,
        'IDProducto': idProductos,
        if (mainUrl != null) 'ImagenProducto': mainUrl,
        'isDescuento': false,
        'montoDescuento': parseNum(_priceCtrl.text) ?? 0.0,
        'porcientoDescuento': 0.0,
      };

      if (isNew) {
        data['IDProductos'] = idProductos;
        data['created_at'] = DateTime.now().toIso8601String();
        data['en_oferta'] = false;
        data['descuento_porcentual'] = 0;
        data['marca'] = 'Omar Studio';
        data['IDEmpresa'] = 'FRFROIJNU821';
        await Supabase.instance.client.from('Productos').insert(data);
      } else {
        await Supabase.instance.client
            .from('Productos')
            .update(data)
            .eq('id', widget.product!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
        setState(() => _isUploading = false);
      }
    }
  }

  Future<String> _uploadImage(XFile file, Uint8List bytes, String productId) async {
    final ext = file.name.split('.').last;
    final path = 'products/$productId-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await Supabase.instance.client.storage.from('general').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
    return Supabase.instance.client.storage.from('general').getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isNew ? 'Nuevo Producto' : 'Editar Producto',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Image picker ──────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: _mainImageBytes != null
                        ? Image.memory(_mainImageBytes!, fit: BoxFit.cover)
                        : (_mainImageUrl != null && _mainImageUrl!.isNotEmpty)
                            ? Image.network(
                                _mainImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imagePlaceholder(),
                              )
                            : _imagePlaceholder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(_mainImageBytes != null || (_mainImageUrl != null && _mainImageUrl!.isNotEmpty)
                        ? 'Cambiar imagen'
                        : 'Subir imagen del producto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Basic info ────────────────────────────────────────────
                CustomTextField(controller: _nameCtrl, label: 'Nombre del Producto', prefixIcon: Icons.shopping_bag_outlined),
                const SizedBox(height: 12),
                CustomTextField(controller: _descCtrl, label: 'Descripción', prefixIcon: Icons.description_outlined, maxLines: 3),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _priceCtrl,
                        label: 'Precio',
                        prefixIcon: Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _stockCtrl,
                        label: 'Stock',
                        prefixIcon: Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Category selection ────────────────────────────────────
                const Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      items: _categories.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Availability for Sale ─────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Apto para Venta al Público', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Switch(
                      value: _disponibleVenta,
                      activeColor: Colors.black,
                      onChanged: (val) {
                        setState(() => _disponibleVenta = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Supplier Info ─────────────────────────────────────────
                CustomTextField(
                  controller: _supplierCtrl,
                  label: 'Contacto del Proveedor (Email/Tel/Nombre)',
                  prefixIcon: Icons.contact_phone_outlined,
                ),
                const SizedBox(height: 12),

                // ── Porcentaje Venta Personal ─────────────────────────────
                CustomTextField(
                  controller: _porcentajeVentaPersonalCtrl,
                  label: 'Porcentaje por venta del personal (%)',
                  prefixIcon: Icons.percent_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 20),

                // ── Applicable Coupons ────────────────────────────────────
                const Text('Cupones Aplicables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (_loadingCoupons)
                  const Center(child: CircularProgressIndicator(color: Colors.black))
                else if (_allCoupons.isEmpty)
                  const Text('No hay cupones registrados en la base de datos.', style: TextStyle(color: Colors.black38, fontSize: 12))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allCoupons.map((c) {
                      final code = c['IDCupon'] as String;
                      final isSelected = _selectedCoupons.contains(code);
                      return FilterChip(
                        label: Text(code),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedCoupons.add(code);
                            } else {
                              _selectedCoupons.remove(code);
                            }
                          });
                        },
                        selectedColor: Colors.black,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 28),

                // ── Actions ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _save,
                        child: _isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Guardar'),
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

  Widget _imagePlaceholder() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 38, color: Colors.black38),
          SizedBox(height: 6),
          Text('Sin imagen', style: TextStyle(color: Colors.black38)),
        ],
      );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _supplierCtrl.dispose();
    _porcentajeVentaPersonalCtrl.dispose();
    super.dispose();
  }
}
