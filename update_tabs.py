import os
import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # 1. Remove _selectedTabIndex state variable
    content = re.sub(r'int\s+_selectedTabIndex\s*=\s*0;\n?', '', content)

    # 2. Update _fetchRecords assignment
    old_records_assign = """        if (_selectedTabIndex == 0) {
          _records = finanzasResp;
        } else {
          _records = ordenesResp;
        }"""
    new_records_assign = """        _records = [...finanzasResp, ...ordenesResp];
        _records.sort((a, b) {
          final fa = a['fecha'] != null ? DateTime.parse(a['fecha']) : DateTime.fromMillisecondsSinceEpoch(0);
          final fb = b['fecha'] != null ? DateTime.parse(b['fecha']) : DateTime.fromMillisecondsSinceEpoch(0);
          return fb.compareTo(fa);
        });"""
    content = content.replace(old_records_assign, new_records_assign)

    # 3. Update the Totals UI texts and variables
    # Left total:
    content = content.replace("formatMoney(_leftSum)", "formatMoney(_globalServicesSum + _globalExtrasSum)")
    content = content.replace("_selectedTabIndex == 0 ? 'Total de servicios' : 'Total productos'", "'Total Servicios'")
    # Right total:
    content = content.replace("formatMoney(_totalEverything)", "formatMoney(_globalProductsSum)")
    content = content.replace("'Total en general (Todo)'", "'Total Productos'")

    # 4. Remove the Tab Selector widget (from Container down to but not including the next major section like Builder)
    # The selector starts with `// Selector de pestaña (Servicios / Productos)`
    # We can use regex to remove it.
    tab_regex = re.compile(r'// Selector de pestaña \(Servicios / Productos\).*?Container\([^)]*\)\s*,\s*\]\s*,\s*\)\s*,\s*\]\s*,\s*\)\s*,\s*\]\s*,\s*\)\s*,\s*\]\s*,\s*\)\s*,\s*', re.DOTALL)
    # Actually regex for nested structures is hard, it's better to just search for the specific lines or do a multi-line regex carefully.
    
    with open(file, 'w') as f:
        f.write(content)
