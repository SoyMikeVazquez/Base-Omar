import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

def extract_brackets(lines, start_idx):
    """Returns the (end_idx, content) of the block starting at start_idx with matching brackets"""
    brace_count = 0
    in_block = False
    for i in range(start_idx, len(lines)):
        line = lines[i]
        brace_count += line.count('{') - line.count('}')
        brace_count += line.count('[') - line.count(']')
        brace_count += line.count('(') - line.count(')')
        
        # Start counting when we see the first opening bracket
        if not in_block and ('{' in line or '[' in line or '(' in line):
            in_block = True
            
        if in_block and brace_count == 0:
            return i
    return start_idx

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

for file in files:
    # Read fresh from original to avoid compounding errors? No, we don't have originals.
    # Let's fix the specific issues in the current file states.
    pass

