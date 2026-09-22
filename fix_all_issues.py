import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Fix duplicate definition
    content = content.replace("double get _globalServicesSum {", "double get _sumServicios {")

    # Fix the double backslash issue
    content = content.replace("value: '\\\\$${", "value: '\\$${")

    # Fix remaining final val = _selectedTabIndex == 0 ? ...
    content = re.sub(
        r"final val = _selectedTabIndex == 0 \? \(r\['total'\] \?\? 0\) : \(r\['suma_productos'\] \?\? 0\);",
        r"final val = (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0) + (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0);",
        content
    )

    # Completely remove any remaining _selectedTabIndex usages that didn't get caught
    # e.g., if (_selectedTabIndex == 0) { ... }
    # Let's just remove the tab UI from finanzas_dashboard_screen.dart and others
    content = re.sub(
        r'          Container\(\n            padding: const EdgeInsets.all\(4\),\n            decoration: BoxDecoration\([\s\S]*?            \),\n          \),\n',
        '', content
    )
    # Another variant of the container
    content = re.sub(
        r'          Container\(\n            margin: const EdgeInsets\.symmetric\(horizontal: 20\),\n            padding: const EdgeInsets.all\(4\),\n            decoration: BoxDecoration\([\s\S]*?            \),\n          \),\n',
        '', content
    )
    
    # Remove all if (_selectedTabIndex != 0) blocks
    content = re.sub(r'\s*if \(_selectedTabIndex != [01]\) \{[\s\S]*?\}', '', content)
    
    # Just in case there are still _selectedTabIndex variables inside chart loop
    content = re.sub(r'if \(_selectedTabIndex == 0\) \{\s*(s \+= .*?;)\s*\} else \{\s*(s \+= .*?;)\s*\}', r'\1', content)
    
    with open(file, 'w') as f:
        f.write(content)

