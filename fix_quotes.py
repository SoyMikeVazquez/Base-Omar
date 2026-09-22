import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    content = content.replace("rec[\'total\']", "rec['total']")
    content = content.replace("rec[\'suma_productos\']", "rec['suma_productos']")
    
    content = content.replace("r[\'total\']", "r['total']")
    content = content.replace("r[\'suma_productos\']", "r['suma_productos']")

    with open(file, 'w') as f:
        f.write(content)

