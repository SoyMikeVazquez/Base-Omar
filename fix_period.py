import os

files = [
    'lib/screens/personal_finance_kpis_screen.dart',
    'lib/screens/finanzas_sucursal_dashboard_screen.dart',
    'lib/screens/finanzas_recepcion_dashboard_screen.dart',
    'lib/screens/finanzas_dashboard_screen.dart',
    'lib/screens/finanzas_generales_dashboard_screen.dart'
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()
    content = content.replace('  _Period _activePeriod = _Period.week;', '  _Period _activePeriod = _Period.today;')
    with open(file, 'w') as f:
        f.write(content)
