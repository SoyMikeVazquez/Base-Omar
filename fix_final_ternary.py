import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # First, globally make sure it's );
    content = content.replace("?? 0.0));", "?? 0.0);")
    
    # Then ONLY in the _showDetails where it is nested, make it ));
    old_nested = """    final total = isGasto
        ? (double.tryParse(rec['Gasto'].toString()) ?? 0.0)
        : (isService
            ? (double.tryParse((rec['total'] ?? 0).toString()) ?? 0.0)
            : (double.tryParse((rec['suma_productos'] ?? 0).toString()) ?? 0.0);"""
    
    new_nested = """    final total = isGasto
        ? (double.tryParse(rec['Gasto'].toString()) ?? 0.0)
        : (isService
            ? (double.tryParse((rec['total'] ?? 0).toString()) ?? 0.0)
            : (double.tryParse((rec['suma_productos'] ?? 0).toString()) ?? 0.0));"""
            
    content = content.replace(old_nested, new_nested)

    with open(file, 'w') as f:
        f.write(content)

