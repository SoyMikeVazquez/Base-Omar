import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # The block we want to fix in the ordenesResp loop:
    old_code_2 = """      for (var r in ordenesResp) {
        final pid = (r['personal_id'] ?? '').toString();
        final total = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
        final suc = (r['sucursal'] ?? '').toString().trim();
        if (pid.isNotEmpty) {
          personalTotals[pid] = (personalTotals[pid] ?? 0.0) + (isGasto ? -total : total);
          personalCounts[pid] = (personalCounts[pid] ?? 0) + 1;
        }
        if (suc.isNotEmpty) {
          sucursalTotals[suc] = (sucursalTotals[suc] ?? 0.0) + (isGasto ? -total : total);
          sucursalCounts[suc] = (sucursalCounts[suc] ?? 0) + 1;
        }
      }"""
        
    new_code_2 = """      for (var r in ordenesResp) {
        final pid = (r['personal_id'] ?? '').toString();
        final total = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
        final suc = (r['sucursal'] ?? '').toString().trim();
        if (pid.isNotEmpty) {
          personalTotals[pid] = (personalTotals[pid] ?? 0.0) + total;
          personalCounts[pid] = (personalCounts[pid] ?? 0) + 1;
        }
        if (suc.isNotEmpty) {
          sucursalTotals[suc] = (sucursalTotals[suc] ?? 0.0) + total;
          sucursalCounts[suc] = (sucursalCounts[suc] ?? 0) + 1;
        }
      }"""

    if old_code_2 in content:
        content = content.replace(old_code_2, new_code_2)
        with open(file, 'w') as f:
            f.write(content)

