import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # 1. Add variable declaration
    if "double _balanceGlobal = 0.0;" not in content:
        content = content.replace(
            "  double _cajaGlobal = 0.0;",
            "  double _cajaGlobal = 0.0;\n  double _balanceGlobal = 0.0;"
        )

    # 2. Add totalIncome calculation inside the loop
    if "double totalIncome = 0.0;" not in content:
        content = content.replace(
            "      double cashIncome = 0.0;\n      double expenses = 0.0;",
            "      double totalIncome = 0.0;\n      double cashIncome = 0.0;\n      double expenses = 0.0;"
        )
        
        # Replace the finanzasResp loop
        old_loop_finanzas = """        if (isGasto) {
          expenses += total;
        } else if (formaPago.contains('efectivo')) {
          cashIncome += total;
        }"""
        new_loop_finanzas = """        if (isGasto) {
          expenses += total;
        } else {
          totalIncome += total;
          if (formaPago.contains('efectivo')) {
            cashIncome += total;
          }
        }"""
        content = content.replace(old_loop_finanzas, new_loop_finanzas)

        # Replace the ordenesResp loop
        old_loop_ordenes = """        if (formaPago.contains('efectivo')) {
          cashIncome += totalProd;
        }"""
        new_loop_ordenes = """        totalIncome += totalProd;
        if (formaPago.contains('efectivo')) {
          cashIncome += totalProd;
        }"""
        content = content.replace(old_loop_ordenes, new_loop_ordenes)

    # 3. Calculate balanceTemp and update setState
    if "double balanceTemp =" not in content:
        content = content.replace(
            "      double cajaTemp = (cashIncome / 2) - expenses;",
            "      double cajaTemp = (cashIncome / 2) - expenses;\n      double balanceTemp = (totalIncome / 2) - expenses;"
        )
        content = content.replace(
            "        _cajaGlobal = cajaTemp;",
            "        _cajaGlobal = cajaTemp;\n        _balanceGlobal = balanceTemp;"
        )
        content = content.replace(
            "        _cajaGlobal = 0.0;",
            "        _cajaGlobal = 0.0;\n        _balanceGlobal = 0.0;"
        )

    # 4. Duplicate the UI container
    # The container we want to duplicate is in _buildCajaSummaryCard
    old_ui = """        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Premium dark look
            borderRadius: BorderRadius.circular(20),
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
                    'Balance de Efectivo (Global)',
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
              const Text(
                '(Ingresos en Efectivo / 2) - Gastos Totales',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),"""

    new_ui = old_ui + """
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Premium dark look
            borderRadius: BorderRadius.circular(20),
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
                    'Balance Total (Todos los métodos)',
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
                formatMoney(_balanceGlobal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '(Ingresos Totales / 2) - Gastos Totales',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),"""

    if "Balance Total (Todos los métodos)" not in content:
        content = content.replace(old_ui, new_ui)

    with open(file, 'w') as f:
        f.write(content)
