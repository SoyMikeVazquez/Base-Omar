import os
import glob

# Files to update
files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()
    
    # Replace the one where isGasto is already defined above it (for expenses sum)
    old_code_1 = """        final isGasto = r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty;
        final total = double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;"""
    new_code_1 = """        final isGasto = r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty;
        final total = isGasto ? (double.tryParse(r['Gasto'].toString()) ?? 0.0) : (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0);"""
    
    content = content.replace(old_code_1, new_code_1)

    # Replace the one in breakdowns (personalTotals / sucursalTotals)
    old_code_2 = """        final pid = (r['personalID'] ?? '').toString();
        final total = double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;
        final suc = (r['sucursal'] ?? '').toString().trim();"""
    new_code_2 = """        final pid = (r['personalID'] ?? '').toString();
        final isGasto = r['Gasto'] != null && r['Gasto'].toString().trim().isNotEmpty;
        final total = isGasto ? (double.tryParse(r['Gasto'].toString()) ?? 0.0) : (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0);
        final suc = (r['sucursal'] ?? '').toString().trim();"""
        
    content = content.replace(old_code_2, new_code_2)

    with open(file, 'w') as f:
        f.write(content)

