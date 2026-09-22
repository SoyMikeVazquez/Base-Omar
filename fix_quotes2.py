import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # The actual string in the dart file is: r[\'total\']
    # So we want to replace the literal characters backslash and quote with just quote.
    content = content.replace(r"rec[\'total\']", "rec['total']")
    content = content.replace(r"rec[\'suma_productos\']", "rec['suma_productos']")
    
    content = content.replace(r"r[\'total\']", "r['total']")
    content = content.replace(r"r[\'suma_productos\']", "r['suma_productos']")

    with open(file, 'w') as f:
        f.write(content)

