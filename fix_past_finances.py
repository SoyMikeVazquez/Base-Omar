import os

file = 'lib/screens/past_finances_screen.dart'
with open(file, 'r') as f:
    content = f.read()

old_code = """      final monto = double.tryParse((t['Monto'] ?? 0).toString()) ?? 0.0;
      final isGasto = t['Gasto'] != null && t['Gasto'].toString().trim().isNotEmpty;
      final formaPago = (t['formadepago'] as String? ?? '').toLowerCase().trim();
      
      if (isGasto) {
        expenses += monto;
      } else if (formaPago.contains('efectivo')) {
        cashIncome += monto;
      }"""

new_code = """      final isGasto = t['Gasto'] != null && t['Gasto'].toString().trim().isNotEmpty;
      final monto = isGasto ? (double.tryParse(t['Gasto'].toString()) ?? 0.0) : (double.tryParse((t['total'] ?? 0).toString()) ?? 0.0);
      final formaPago = (t['formadepago'] as String? ?? '').toLowerCase().trim();
      
      if (isGasto) {
        expenses += monto;
      } else if (formaPago.contains('efectivo')) {
        cashIncome += monto;
      }"""

content = content.replace(old_code, new_code)

with open(file, 'w') as f:
    f.write(content)
