import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # 1. Reset everything to single parenthesis
    content = content.replace("?? 0.0));", "?? 0.0);")
    
    # 2. Fix nested ones with rec
    content = re.sub(
        r': \(isService\n\s*\? \(double\.tryParse\(\(rec\[\'total\'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0\)\n\s*: \(double\.tryParse\(\(rec\[\'suma_productos\'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0\);',
        r': (isService\n            ? (double.tryParse((rec[\'total\'] ?? 0).toString()) ?? 0.0)\n            : (double.tryParse((rec[\'suma_productos\'] ?? 0).toString()) ?? 0.0));',
        content
    )
    
    # 3. Fix nested ones with r (if any)
    content = re.sub(
        r': \(isService\n\s*\? \(double\.tryParse\(\(r\[\'total\'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0\)\n\s*: \(double\.tryParse\(\(r\[\'suma_productos\'\] \?\? 0\)\.toString\(\)\) \?\? 0\.0\);',
        r': (isService\n            ? (double.tryParse((r[\'total\'] ?? 0).toString()) ?? 0.0)\n            : (double.tryParse((r[\'suma_productos\'] ?? 0).toString()) ?? 0.0));',
        content
    )

    with open(file, 'w') as f:
        f.write(content)

