import os
import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # 1. Update text for Registros title
    content = content.replace("_selectedTabIndex == 0 ? 'Registros' : 'Órdenes'", "'Historial de Registros'")
    
    # 2. Update length text
    old_length_text = """                      _selectedTabIndex == 0
                          ? '${filteredRecords.length} total'
                          : '${filteredRecords.length} orden${filteredRecords.length != 1 ? 'es' : ''}',"""
    new_length_text = "                      '${filteredRecords.length} en total',"
    content = content.replace(old_length_text, new_length_text)

    # 3. Update `final isService = _selectedTabIndex == 0;` to `!r.containsKey('suma_productos');`
    content = content.replace("final isService = _selectedTabIndex == 0;", "final isService = !r.containsKey('suma_productos');")

    # 4. Remove tab selector UI block
    # It starts with `// Selector de pestaña (Servicios / Productos)`
    # And ends before `        ],` that closes the Column containing `// Totales ...` and `// Selector ...`
    # Let's use regex.
    # The structure is:
    #           // Selector de pestaña (Servicios / Productos)
    #           Container(
    #             ...
    #           ),
    #         ],
    pattern = re.compile(r'\s*// Selector de pestaña \(Servicios / Productos\).*?Container\([^)]*\)\s*,\s*\]\s*,\s*\)\s*,\s*\]\s*,\s*\)\s*,\s*\]\s*,\s*\)\s*,\s*\]\s*,\s*\)\s*,\s*', re.DOTALL)
    # This regex is risky if I get the closing brackets wrong.
    # Alternative: find "// Selector de pestaña" and remove everything until "        ]," (inclusive or exclusive)
    
    lines = content.split('\n')
    new_lines = []
    skip = False
    brace_count = 0
    for i, line in enumerate(lines):
        if '// Selector de pestaña (Servicios / Productos)' in line:
            skip = True
            brace_count = 0
            continue
            
        if skip:
            brace_count += line.count('(') - line.count(')')
            brace_count += line.count('[') - line.count(']')
            brace_count += line.count('{') - line.count('}')
            # We assume it ends when brace count drops to 0 and line has `          ),` or similar.
            # A simpler approach: we know exactly what is below it. It is: `        ],` then `      ),`
            if '        ],' in line and brace_count <= 0:
                skip = False
                new_lines.append(line)
            continue
            
        new_lines.append(line)
        
    content = '\n'.join(new_lines)
    
    with open(file, 'w') as f:
        f.write(content)
