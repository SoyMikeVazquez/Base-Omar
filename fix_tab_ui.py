import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Remove the Container that holds the tabs
    # We find "          Container(" followed by the tabs content.
    pattern = re.compile(r'          const SizedBox\(height: 20\),\n\n          Container\(\n            padding: const EdgeInsets.all\(4\),\n            decoration: BoxDecoration\([\s\S]*?            \),\n          \),\n', re.MULTILINE)
    content = pattern.sub('', content)

    # Also fix final val = _selectedTabIndex ...
    content = re.sub(r'final val = _selectedTabIndex == 0 \? \(r\[\'total\'\] \?\? 0\) : \(r\[\'suma_productos\'\] \?\? 0\);',
                     r"final val = (double.tryParse((r['total'] ?? 0).toString()) ?? 0.0) + (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0);", content)

    with open(file, 'w') as f:
        f.write(content)

