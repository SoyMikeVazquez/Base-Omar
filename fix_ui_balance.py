import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    if "Balance Total (Todos los métodos)" in content:
        continue

    # Find the _buildCajaSummaryCard function
    pattern = r'(Widget _buildCajaSummaryCard\(\) \{.*?)(        \),\n      \],\n    \);\n  })'
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        old_block = match.group(0)
        
        # We need to extract the exact styling used for the first container
        # Let's find if it uses withOpacity or withValues
        opacity_str = "withOpacity(0.1)"
        if "withValues(alpha: 0.1)" in old_block:
            opacity_str = "withValues(alpha: 0.1)"
            
        new_container = f"""        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Premium dark look
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.{opacity_str},
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
                      color: Colors.white.{opacity_str},
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
        
        new_block = match.group(1) + new_container + "\n" + match.group(2)
        content = content.replace(old_block, new_block)
        
        with open(file, 'w') as f:
            f.write(content)

