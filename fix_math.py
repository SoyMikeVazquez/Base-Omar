import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Update math logic
    content = content.replace(
        "double cajaTemp = (cashIncome - expenses) / 2;",
        "double cajaTemp = (cashIncome / 2) - expenses;"
    )

    # Update UI text
    content = content.replace(
        "'(Ingresos en Efectivo - Gastos Totales) / 2'",
        "'(Ingresos en Efectivo / 2) - Gastos Totales'"
    )

    with open(file, 'w') as f:
        f.write(content)

