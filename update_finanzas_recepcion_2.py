import re

with open('lib/screens/finanzas_recepcion_screen.dart', 'r') as f:
    content = f.read()

# Add _customCommissions map
content = content.replace(
    '  final Map<String, double> _customPrices = {};',
    '  final Map<String, double> _customPrices = {};\n  final Map<String, double> _customCommissions = {};'
)

# Remove _showEditPriceDialog
# We need to find the whole method. It starts at Future<void> _showEditPriceDialog and ends before void initState
start_idx = content.find('  Future<void> _showEditPriceDialog')
end_idx = content.find('  @override\n  void initState() {')
if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + content[end_idx:]

# Replace the product list rendering
old_product_rendering = '''                            if (_productos.isEmpty)
                              const _EmptyChipHint(label: 'No hay productos disponibles')
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _productos.map((p) {
                                  final id = p['id'].toString();
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
                                    onAdd: () {
                                      if (qty < stock) {
                                        setState(() {
                                          _selectedProductos[id] = qty + 1;
                                        });
                                      }
                                    },
                                    onRemove: () {
                                      if (qty > 0) {
                                        setState(() {
                                          _selectedProductos[id] = qty - 1;
                                          if (_selectedProductos[id] == 0) {
                                            _selectedProductos.remove(id);
                                          }
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),'''

new_product_rendering = '''                            if (_productos.isEmpty)
                              const _EmptyChipHint(label: 'No hay productos disponibles')
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Mostrar productos seleccionados como tarjetas con campos
                                  if (_selectedProductos.isNotEmpty) ...[
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _selectedProductos.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                      itemBuilder: (ctx, i) {
                                        final id = _selectedProductos.keys.elementAt(i);
                                        final qty = _selectedProductos.values.elementAt(i);
                                        final p = _productos.firstWhere((p) => p['id'].toString() == id);
                                        final name = p['nombre'] ?? '';
                                        final stock = p['stock'] as int? ?? 0;
                                        
                                        final defaultPrice = _productoPrices[id] ?? 0.0;
                                        final price = _customPrices[id] ?? defaultPrice;
                                        
                                        final pvp = double.tryParse(p['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
                                        final defaultComm = price * (pvp / 100.0);
                                        final commission = _customCommissions[id] ?? defaultComm;

                                        return _SelectedProductCard(
                                          name: name,
                                          price: price,
                                          commission: commission,
                                          stock: stock,
                                          quantity: qty,
                                          onAdd: () {
                                            if (qty < stock) {
                                              setState(() => _selectedProductos[id] = qty + 1);
                                            }
                                          },
                                          onRemove: () {
                                            if (qty > 0) {
                                              setState(() {
                                                _selectedProductos[id] = qty - 1;
                                                if (_selectedProductos[id] == 0) {
                                                  _selectedProductos.remove(id);
                                                  _customPrices.remove(id);
                                                  _customCommissions.remove(id);
                                                }
                                              });
                                            }
                                          },
                                          onPriceChanged: (newPrice) {
                                            setState(() {
                                              _customPrices[id] = newPrice;
                                              // Recalcular comisión por defecto si cambian el precio y no la habían personalizado
                                              if (!_customCommissions.containsKey(id)) {
                                                _customCommissions[id] = newPrice * (pvp / 100.0);
                                              }
                                            });
                                          },
                                          onCommissionChanged: (newComm) {
                                            setState(() => _customCommissions[id] = newComm);
                                          }
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Agregar más productos:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 8),
                                  ],
                                  
                                  // Mostrar productos NO seleccionados como chips
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _productos.where((p) => !(_selectedProductos.containsKey(p['id'].toString()) && _selectedProductos[p['id'].toString()]! > 0)).map((p) {
                                      final id = p['id'].toString();
                                      final name = p['nombre'] ?? '';
                                      final price = _productoPrices[id] ?? 0.0;
                                      
                                      return ActionChip(
                                        backgroundColor: const Color(0xFFF2F2F7),
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        label: Text('$name (\$${price.toInt()})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                        onPressed: () {
                                          if ((p['stock'] as int? ?? 0) > 0) {
                                            setState(() => _selectedProductos[id] = 1);
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),'''

content = content.replace(old_product_rendering, new_product_rendering)

# Replace comisionActual calculation in the UI (green box)
old_comision_actual_ui = '''                                  double comisionActual = 0.0;
                                  for (var entry in _selectedProductos.entries) {
                                    final prod = _productos.firstWhere((p) => p['id'].toString() == entry.key);
                                    final double pPrice = _customPrices[entry.key] ?? _productoPrices[entry.key] ?? 0.0;
                                    final double pvp = double.tryParse(prod['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
                                    if (pvp > 0) {
                                      comisionActual += (pPrice * (pvp / 100.0)) * entry.value;
                                    }
                                  }'''
new_comision_actual_ui = '''                                  double comisionActual = 0.0;
                                  for (var entry in _selectedProductos.entries) {
                                    final prod = _productos.firstWhere((p) => p['id'].toString() == entry.key);
                                    final double pPrice = _customPrices[entry.key] ?? _productoPrices[entry.key] ?? 0.0;
                                    final double pvp = double.tryParse(prod['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
                                    final defaultComm = pPrice * (pvp / 100.0);
                                    final customComm = _customCommissions[entry.key] ?? defaultComm;
                                    comisionActual += customComm * entry.value;
                                  }'''
content = content.replace(old_comision_actual_ui, new_comision_actual_ui)

# Replace comisionTotalProductos in _submit()
old_comision_submit = '''        // Calcular comisión por venta de productos de forma dinámica
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
        }'''
new_comision_submit = '''        // Calcular comisión por venta de productos de forma dinámica
        double comisionTotalProductos = 0.0;
        if (_showProducts) {
          for (var entry in _selectedProductos.entries) {
            final prod = _productos.firstWhere((p) => p['id'].toString() == entry.key);
            final double price = _customPrices[entry.key] ?? _productoPrices[entry.key] ?? 0.0;
            final double pvp = double.tryParse(prod['porcentaje_venta_personal']?.toString() ?? '0') ?? 0.0;
            final defaultComm = price * (pvp / 100.0);
            final customComm = _customCommissions[entry.key] ?? defaultComm;
            comisionTotalProductos += customComm * entry.value;
          }
        }'''
content = content.replace(old_comision_submit, new_comision_submit)


# Remove old _ProductChip and insert new _SelectedProductCard
old_chip_class = '''class _ProductChip extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.black : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Colors.black : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\\$${price % 1 == 0 ? price.toInt() : price} • Stock: $stock',
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white70 : Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Row(
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
                  decoration: BoxDecoration(
                    color: selected ? Colors.white24 : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove, size: 14, color: selected ? Colors.white : Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$quantity',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white24 : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, size: 14, color: selected ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}'''

new_card_class = '''class _SelectedProductCard extends StatefulWidget {
  final String name;
  final double price;
  final double commission;
  final int stock;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<double> onCommissionChanged;

  const _SelectedProductCard({
    required this.name,
    required this.price,
    required this.commission,
    required this.stock,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    required this.onPriceChanged,
    required this.onCommissionChanged,
  });

  @override
  State<_SelectedProductCard> createState() => _SelectedProductCardState();
}

class _SelectedProductCardState extends State<_SelectedProductCard> {
  late TextEditingController _priceCtrl;
  late TextEditingController _commCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.price.toStringAsFixed(2));
    _commCtrl = TextEditingController(text: widget.commission.toStringAsFixed(2));
  }
  
  @override
  void didUpdateWidget(_SelectedProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.price != widget.price && double.tryParse(_priceCtrl.text) != widget.price) {
      _priceCtrl.text = widget.price.toStringAsFixed(2);
    }
    if (oldWidget.commission != widget.commission && double.tryParse(_commCtrl.text) != widget.commission) {
      _commCtrl.text = widget.commission.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _commCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.remove, size: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${widget.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Precio Unitario', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixText: '\\$ ',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          final newVal = double.tryParse(val);
                          if (newVal != null) widget.onPriceChanged(newVal);
                        },
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
                    const Text('Comisión (p/pza)', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _commCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green),
                        decoration: InputDecoration(
                          prefixText: '\\$ ',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          final newVal = double.tryParse(val);
                          if (newVal != null) widget.onCommissionChanged(newVal);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}'''

content = content.replace(old_chip_class, new_card_class)

with open('lib/screens/finanzas_recepcion_screen.dart', 'w') as f:
    f.write(content)
