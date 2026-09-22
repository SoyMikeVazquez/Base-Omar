import glob

files = [
    'lib/screens/finanzas_generales_dashboard_screen.dart',
    'lib/screens/finanzas_sucursal_dashboard_screen.dart',
    'lib/screens/finanzas_recepcion_dashboard_screen.dart'
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # 1. Add state variable
    if 'Map<String, double> _sucursalTotals = {};' in content and 'Map<String, double> _sucursalGastos = {};' not in content:
        content = content.replace(
            'Map<String, double> _sucursalTotals = {};',
            'Map<String, double> _sucursalTotals = {};\n  Map<String, double> _sucursalGastos = {};'
        )

    # 2. Add sucursalGastos calculation in load method
    old_calc_init = 'final Map<String, double> sucursalTotals = {};'
    new_calc_init = 'final Map<String, double> sucursalTotals = {};\n      final Map<String, double> sucursalGastos = {};'
    if old_calc_init in content and new_calc_init not in content:
        content = content.replace(old_calc_init, new_calc_init)

    old_calc_loop = """        if (suc.isNotEmpty) {
          sucursalTotals[suc] = (sucursalTotals[suc] ?? 0.0) + (isGasto ? -total : total);
          sucursalCounts[suc] = (sucursalCounts[suc] ?? 0) + 1;
        }"""
    new_calc_loop = """        if (suc.isNotEmpty) {
          sucursalTotals[suc] = (sucursalTotals[suc] ?? 0.0) + (isGasto ? -total : total);
          sucursalCounts[suc] = (sucursalCounts[suc] ?? 0) + 1;
          if (isGasto) {
            sucursalGastos[suc] = (sucursalGastos[suc] ?? 0.0) + total;
          }
        }"""
    if old_calc_loop in content:
        content = content.replace(old_calc_loop, new_calc_loop)

    old_set_state = '_sucursalTotals = sucursalTotals;'
    new_set_state = '_sucursalTotals = sucursalTotals;\n        _sucursalGastos = sucursalGastos;'
    if old_set_state in content and '_sucursalGastos = sucursalGastos;' not in content:
        content = content.replace(old_set_state, new_set_state)

    old_reset_state = '_sucursalTotals = {};'
    new_reset_state = '_sucursalTotals = {};\n        _sucursalGastos = {};'
    if old_reset_state in content and '_sucursalGastos = {};' not in content:
        content = content.replace(old_reset_state, new_reset_state)

    # 3. Update UI card
    # Increase height of ListView in _buildSucursalBreakdown
    old_height = 'SizedBox(\n          height: 100,'
    new_height = 'SizedBox(\n          height: 114,'
    if old_height in content:
        content = content.replace(old_height, new_height)
    
    old_height_2 = 'SizedBox(\n          height: 105,'
    new_height_2 = 'SizedBox(\n          height: 114,'
    if old_height_2 in content:
        content = content.replace(old_height_2, new_height_2)

    # Add gastos in the card Column
    old_card_col = """                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\\$${formatMoney(total)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '$count registro${count != 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 10, color: Colors.black38),
                        ),
                      ],
                    ),"""
    new_card_col = """                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\\$${formatMoney(total)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '$count registro${count != 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 10, color: Colors.black38),
                        ),
                        if ((_sucursalGastos[suc] ?? 0.0) > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Gastos: \\$${formatMoney(_sucursalGastos[suc] ?? 0.0)}',
                            style: TextStyle(fontSize: 10, color: Colors.red.shade600, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),"""

    if old_card_col in content:
        content = content.replace(old_card_col, new_card_col)

    with open(file, 'w') as f:
        f.write(content)
    print(f"Updated {file}")

