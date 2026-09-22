import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Remove unused getters _leftSum and _totalEverything
    content = re.sub(r'  double get _leftSum \{[\s\S]*?\}\n', '', content)
    content = re.sub(r'  double get _totalEverything \{[\s\S]*?\}\n', '', content)
    
    # Fix the double parse in the charting functions where _selectedTabIndex was used
    content = re.sub(r'      if \(_selectedTabIndex == 0\) \{\s*s \+= double\.tryParse\(\(r\[\'total\'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0;\s*\} else \{\s*s \+= double\.tryParse\(\(r\[\'suma_productos\'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0;\s*\}', 
                     r"      s += (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0) + (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0);", content)

    # _buildMetricCards rewrite to include both
    metric_cards_regex = re.compile(r'  Widget _buildMetricCards\(\) \{[\s\S]*?    \}\n  \}', re.MULTILINE)
    
    new_metric_cards = """  Widget _buildMetricCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: _MetricCard(
              icon: Icons.receipt_long_rounded,
              label: 'Registros',
              value: '${_records.length}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: _MetricCard(
              icon: Icons.design_services_rounded,
              label: 'Servicios',
              value: '\\$${formatMoney(_sumServicios, decimalDigits: 0)}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: _MetricCard(
              icon: Icons.shopping_bag_outlined,
              label: 'Productos',
              value: '\\$${formatMoney(_sumProductos, decimalDigits: 0)}',
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: _MetricCard(
              icon: Icons.add_circle_outline_rounded,
              label: 'Extras',
              value: '\\$${formatMoney(_sumMontosExtras, decimalDigits: 0)}',
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }"""
    content = metric_cards_regex.sub(new_metric_cards.replace('\\$', '$'), content)

    with open(file, 'w') as f:
        f.write(content)

