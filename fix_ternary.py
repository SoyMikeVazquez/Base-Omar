import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Fix the missing closing parenthesis for ternary operator using r
    content = content.replace(
        ": (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0);",
        ": (double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0));"
    )
    
    # Fix the missing closing parenthesis for ternary operator using rec
    content = content.replace(
        ": (double.tryParse((rec['suma_productos'] ?? 0).toString()) ?? 0.0);",
        ": (double.tryParse((rec['suma_productos'] ?? 0).toString()) ?? 0.0));"
    )

    with open(file, 'w') as f:
        f.write(content)

