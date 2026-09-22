import os

file = 'lib/screens/personal_finance_kpis_screen.dart'
with open(file, 'r') as f:
    content = f.read()

old_code = """        final r = services[index];
        final fecha = r['fecha'] != null ? DateTime.parse(r['fecha'].toString()).toLocal() : null;
        final total = double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;
        final formaPago = r['formadepago'] as String? ?? 'En efectivo';"""

new_code = """        final r = services[index];
        final fecha = r['fecha'] != null ? DateTime.parse(r['fecha'].toString()).toLocal() : null;
        final isGasto = r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty;
        final total = isGasto ? (double.tryParse(r['Gasto'].toString()) ?? 0.0) : (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0);
        final formaPago = r['formadepago'] as String? ?? 'En efectivo';"""

content = content.replace(old_code, new_code)

with open(file, 'w') as f:
    f.write(content)
