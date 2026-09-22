import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Fix the missing escape and use the correct variables
    content = content.replace("value: '$${formatMoney(_sumServicios, decimalDigits: 0)}',", "value: '\\\\$${formatMoney(_sumServicios, decimalDigits: 0)}',")
    content = content.replace("value: '$${formatMoney(_sumProductos, decimalDigits: 0)}',", "value: '\\\\$${formatMoney(_globalProductsSum, decimalDigits: 0)}',")
    content = content.replace("value: '$${formatMoney(_sumMontosExtras, decimalDigits: 0)}',", "value: '\\\\$${formatMoney(_globalExtrasSum, decimalDigits: 0)}',")

    # In case _sumServicios isn't defined or we just want to use the global sums:
    content = content.replace("_sumServicios", "_globalServicesSum")

    with open(file, 'w') as f:
        f.write(content)

