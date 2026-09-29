# Regla: Zonas Protegidas y No Modificables

## Archivos y Pantallas Congelados

No modificar, editar ni alterar de ninguna forma el código de:
1. `lib/screens/dashboard_super_admin.dart` (Dashboard Superadmin/Propietario).
2. `lib/screens/dashboard_admin.dart` y `lib/screens/dashboard_recepcion.dart` (Dashboards Personal / Empleados / Recepción).
3. `lib/screens/finanzas_generales_dashboard_screen.dart` (Módulo de Finanzas Generales, gráficas, totales, desglose de sucursal/personal/caja e historial de registros).
4. El visor y modal de detalles que abre cada elemento del `ListView` en Finanzas Generales.
5. Archivos de finanzas asociados:
   - `lib/screens/finanzas_dashboard_screen.dart`
   - `lib/screens/finanzas_personal_screen.dart`
   - `lib/screens/finanzas_recepcion_dashboard_screen.dart`
   - `lib/screens/finanzas_recepcion_screen.dart`
   - `lib/screens/finanzas_sucursal_dashboard_screen.dart`
   - `lib/screens/finanzas_filtered_records_screen.dart`
   - `lib/screens/gastos_filtered_records_screen.dart`
   - `lib/screens/past_finances_screen.dart`
   - `lib/screens/personal_finance_kpis_screen.dart`

Todo trabajo o desarrollo futuro debe abstenerse de modificar estos archivos a menos que el usuario lo pida explícitamente.
