# Reglas del Proyecto - Zonas Protegidas y No Modificables

> **IMPORTANTE**: Este archivo establece reglas estrictas y permanentes para cualquier asistente de IA o desarrollador que trabaje en esta base de código.

---

## 🔒 Zonas Protegidas / Archivos Congelados (DO NOT TOUCH)

Bajo **ninguna circunstancia** se deben realizar modificaciones, refactorizaciones ni alteraciones al código actualmente implementado en las siguientes pantallas y componentes, salvo que el usuario lo autorice **explícita y puntualmente**:

### 1. Dashboard de Superadministrador / Propietario
- `lib/screens/dashboard_super_admin.dart`
- Resumen general, métricas, gráficas y accesos del propietario.

### 2. Dashboard de Personal / Administrador / Recepción
- `lib/screens/dashboard_admin.dart` (Dashboard de empleados/personal)
- `lib/screens/dashboard_recepcion.dart` (Dashboard de recepción)
- Tarjeta de ganancias, estatus de citas, inventario asignado y flujo de trabajo diario.

### 3. Módulo de Finanzas Generales
- `lib/screens/finanzas_generales_dashboard_screen.dart`
  - Resumen de ingresos (Servicios y Productos).
  - Filtros de tiempo (Hoy, Ayer, Antier, Personalizado).
  - Gráfica de tendencia de ingresos (vista individual/global).
  - Sección de Ingresos por Personal.
  - Sección de Ingresos por Sucursal (Ingresos, Gastos, Balance).
  - Resumen por Métodos de Pago (Efectivo, Tarjeta, Transferencia, etc.).
  - Efectivo en Caja (Balance de la caja | Efectivo - Gastos).
  - Historial de registros (`ListView`).
  - **Detalles de registros de finanzas**: El modal / bottom sheet que se abre al hacer clic en cualquier elemento de la lista (ver detalles del servicio/gasto, desglose, formas de pago, botones de editar/eliminar).

### 4. Pantallas y Submódulos de Finanzas Relacionadas
- `lib/screens/finanzas_dashboard_screen.dart`
- `lib/screens/finanzas_personal_screen.dart`
- `lib/screens/finanzas_recepcion_dashboard_screen.dart`
- `lib/screens/finanzas_recepcion_screen.dart`
- `lib/screens/finanzas_sucursal_dashboard_screen.dart`
- `lib/screens/finanzas_filtered_records_screen.dart`
- `lib/screens/gastos_filtered_records_screen.dart`
- `lib/screens/past_finances_screen.dart`
- `lib/screens/personal_finance_kpis_screen.dart`

---

## 🛑 Directiva de Comportamiento para Futuras Tareas

1. **Inmutabilidad de código existente**:
   - Todo nuevo desarrollo, implementación de pantallas, correcciones en otros módulos o adiciones de funcionalidades deben respetar al 100% el código actual de las pantallas protegidas.
   - **No alterar llamadas a Supabase**, queries, cálculo de totales, lógica de negocio ni widgets de las finanzas y dashboards mencionados.
2. **Si una nueva función requiere datos de finanzas**:
   - Se debe construir un servicio o pantalla independiente sin alterar las pantallas existentes.
3. **Confirmación obligatoria**:
   - Si una solicitud futura del usuario pudiera tener impacto indirecto en estas pantallas, el asistente debe advertirlo de antemano y abstenerse de modificar los archivos protegidos.
