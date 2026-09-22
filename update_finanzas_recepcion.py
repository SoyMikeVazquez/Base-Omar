import re

with open('lib/screens/finanzas_recepcion_screen.dart', 'r') as f:
    content = f.read()

# Add _customPrices
content = content.replace(
    '  final Map<String, double> _productoPrices = {};',
    '  final Map<String, double> _productoPrices = {};\n  final Map<String, double> _customPrices = {};'
)

# Modify _sumaProductos
new_suma_productos = '''  double get _sumaProductos {
    double sum = 0;
    _selectedProductos.forEach((id, qty) {
      sum += (_customPrices[id] ?? _productoPrices[id] ?? 0.0) * qty;
    });
    return sum;
  }
'''
content = re.sub(r'  double get _sumaProductos \{\s+double sum = 0;\s+_selectedProductos.forEach\(\(id, qty\) \{\s+sum \+= \(_productoPrices\[id\] \?\? 0\.0\) \* qty;\s+\}\);\s+return sum;\s+\}', new_suma_productos, content)

# Add _showEditPriceDialog
edit_price_dialog = '''  Future<void> _showEditPriceDialog(String productId, String productName, double currentPrice) async {
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

  void _initData'''
content = content.replace('  void initState() {', edit_price_dialog.replace('  void _initData', '  void initState() {'))

# Modify submit logic
old_submit_logic = '''        // Calcular posible comisión por venta de "pomada base agua"
        double comisionPomada = 0.0;
        if (_showProducts) {
          for (var entry in _selectedProductos.entries) {
            final prod = _productos.firstWhere((p) => p['id'].toString() == entry.key);
            final nombre = (prod['nombre'] ?? prod['NombreProducto'] ?? '').toString().toLowerCase();
            if (nombre.contains('pomada') && nombre.contains('agua')) {
              comisionPomada += 50.0 * entry.value;
            }
          }
        }

        // 1. Guardar Registro de Servicios si aplica (o si hay comisión por registrar)
        if (_showServices || comisionPomada > 0) {
          final serviciosDetalle = _selectedServiceIds.map((id) {
            final s = _services.firstWhere((e) => e['id'].toString() == id);
            return {
              'id': id,
              'name': s['nameService'],
              'price': _servicePrices[id] ?? 0.0,
            };
          }).toList();

          final double extrasFinal = _montosExtras + comisionPomada;
          String descFinal = _descripcionExtrasController.text.trim();
          if (comisionPomada > 0) {
            descFinal += (descFinal.isEmpty ? '' : ' | ') + 'Comisión por Pomada (+$\\$comisionPomada)';
          }'''

new_submit_logic = '''        // Calcular comisión por venta de productos de forma dinámica
        double comisionTotalProductos = 0.0;
        if (_showProducts) {
          for (var entry in _selectedProductos.entries) {
            final prod = _productos.firstWhere((p) => p['id'].toString() == entry.key);
            final double price = _customPrices[entry.key] ?? _productoPrices[entry.key] ?? 0.0;
            final double pvp = double.tryParse(prod['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
            if (pvp > 0) {
              comisionTotalProductos += (price * (pvp / 100.0)) * entry.value;
            }
          }
        }

        // 1. Guardar Registro de Servicios si aplica (o si hay comisión por registrar)
        if (_showServices || comisionTotalProductos > 0) {
          final serviciosDetalle = _selectedServiceIds.map((id) {
            final s = _services.firstWhere((e) => e['id'].toString() == id);
            return {
              'id': id,
              'name': s['nameService'],
              'price': _servicePrices[id] ?? 0.0,
            };
          }).toList();

          final double extrasFinal = _montosExtras + comisionTotalProductos;
          String descFinal = _descripcionExtrasController.text.trim();
          if (comisionTotalProductos > 0) {
            descFinal += (descFinal.isEmpty ? '' : ' | ') + 'Comisión por productos (+$\\$comisionTotalProductos)';
          }'''
content = content.replace(old_submit_logic, new_submit_logic)

# Guardar Orden de Productos - fix unit price
content = content.replace(
    "'precio_unitario': _productoPrices[e.key] ?? 0.0,",
    "'precio_unitario': _customPrices[e.key] ?? _productoPrices[e.key] ?? 0.0,"
)
content = content.replace(
    "'subtotal': (_productoPrices[e.key] ?? 0.0) * e.value,",
    "'subtotal': (_customPrices[e.key] ?? _productoPrices[e.key] ?? 0.0) * e.value,"
)

# Email ticket items - fix product prices
old_ticket_logic = '''        if (_showProducts) {
          _selectedProductos.forEach((id, qty) {
            final prod = _productos.firstWhere((p) => p['id'].toString() == id);
            items.add({
              'name': prod['nombre'],
              'price': _productoPrices[id] ?? 0.0,
              'qty': qty,
            });
          });
        }'''
new_ticket_logic = '''        if (_showProducts) {
          _selectedProductos.forEach((id, qty) {
            final prod = _productos.firstWhere((p) => p['id'].toString() == id);
            items.add({
              'name': prod['nombre'],
              'price': _customPrices[id] ?? _productoPrices[id] ?? 0.0,
              'qty': qty,
            });
          });
        }'''
content = content.replace(old_ticket_logic, new_ticket_logic)

# Modify Product UI rendering in the list
old_product_mapping = '''                                  final id = p['id'].toString();
                                  final name = p['nombre'] ?? '';
                                  final price = _productoPrices[id] ?? 0.0;
                                  final stock = p['stock'] as int? ?? 0;
                                  final qty = _selectedProductos[id] ?? 0;
                                  
                                  return _ProductChip(
                                    name: name,
                                    price: price,
                                    stock: stock,
                                    quantity: qty,
                                    onAdd: () {'''
new_product_mapping = '''                                  final id = p['id'].toString();
                                  final name = p['nombre'] ?? '';
                                  final price = _customPrices[id] ?? _productoPrices[id] ?? 0.0;
                                  final stock = p['stock'] as int? ?? 0;
                                  final qty = _selectedProductos[id] ?? 0;
                                  
                                  return _ProductChip(
                                    name: name,
                                    price: price,
                                    stock: stock,
                                    quantity: qty,
                                    onEditPrice: () => _showEditPriceDialog(id, name, price),
                                    onAdd: () {'''
content = content.replace(old_product_mapping, new_product_mapping)

# Add commission summary below product list
old_summary_header = '''                            if (_selectedProductos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration('''
new_summary_header = '''                            if (_selectedProductos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Builder(
                                builder: (ctx) {
                                  double comisionActual = 0.0;
                                  for (var entry in _selectedProductos.entries) {
                                    final prod = _productos.firstWhere((p) => p['id'].toString() == entry.key);
                                    final double pPrice = _customPrices[entry.key] ?? _productoPrices[entry.key] ?? 0.0;
                                    final double pvp = double.tryParse(prod['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
                                    if (pvp > 0) {
                                      comisionActual += (pPrice * (pvp / 100.0)) * entry.value;
                                    }
                                  }
                                  if (comisionActual > 0) {
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
                                            'Comisión estimada para el personal: \\$${comisionActual.toStringAsFixed(2)}',
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
                                decoration: BoxDecoration('''
content = content.replace(old_summary_header, new_summary_header)


# Modify _ProductChip class
old_chip_start = '''class _ProductChip extends StatelessWidget {
  final String name;
  final double price;
  final int stock;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductChip({
    required this.name,
    required this.price,
    required this.stock,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });'''
new_chip_start = '''class _ProductChip extends StatelessWidget {
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
  });'''
content = content.replace(old_chip_start, new_chip_start)

# Add edit icon to _ProductChip
old_chip_row = '''          Row(
            children: [
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration('''
new_chip_row = '''          Row(
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
                  decoration: BoxDecoration('''
content = content.replace(old_chip_row, new_chip_row)

with open('lib/screens/finanzas_recepcion_screen.dart', 'w') as f:
    f.write(content)
