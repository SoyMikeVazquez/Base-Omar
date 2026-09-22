import re

# 1. finanzas_dashboard_screen.dart
with open('lib/screens/finanzas_dashboard_screen.dart', 'r') as f:
    content = f.read()

# Replace chart logic
chart_logic = r'''            double val = 0;
            if \(_selectedTabIndex == 0\) \{
              final serv = double\.tryParse\(\(r\['suma_servicios'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0;
              final ext = double\.tryParse\(\(r\['montos_extras'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0;
              val = \(serv \* 0\.50\) \+ ext;
            \} else \{
              val = double\.tryParse\(\(r\['suma_productos'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0;
            \}
            s \+= val;'''
new_chart_logic = r'''            final serv = double.tryParse((r['suma_servicios'] ?? 0).toString()) ?? 0.0;
            final ext = double.tryParse((r['montos_extras'] ?? 0).toString()) ?? 0.0;
            final prod = double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
            s += (serv * 0.50) + ext + prod;'''

content = re.sub(chart_logic, new_chart_logic, content)

# 1205: _selectedTabIndex == 0 ? ... : ...
# Since we merged, we can just show _records.length or whatever it was
content = re.sub(r'_selectedTabIndex == 0\s*\?\s*(\w+)\.length\s*:\s*(\w+)\.length', r'_records.length', content)

with open('lib/screens/finanzas_dashboard_screen.dart', 'w') as f:
    f.write(content)

# 2. finanzas_recepcion_dashboard_screen.dart
with open('lib/screens/finanzas_recepcion_dashboard_screen.dart', 'r') as f:
    content = f.read()

content = re.sub(r'_selectedTabIndex == 0\s*\?\s*(\w+)\.length\s*:\s*(\w+)\.length', r'_records.length', content)

with open('lib/screens/finanzas_recepcion_dashboard_screen.dart', 'w') as f:
    f.write(content)

