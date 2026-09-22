import 'package:flutter/material.dart';
import 'package:totalpro/utils/formatters.dart';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../widgets/universal_footer_buttons.dart';
import 'finanzas_generales_dashboard_screen.dart';
import 'finanzas_sucursal_dashboard_screen.dart';
import 'general_agenda_screen.dart';
import 'personal_finance_kpis_screen.dart';
import 'past_finances_screen.dart';
import 'ai_chat_screen.dart';

class DashboardSuperAdmin extends StatefulWidget {
  const DashboardSuperAdmin({super.key});

  @override
  State<DashboardSuperAdmin> createState() => _DashboardSuperAdminState();
}

class _DashboardSuperAdminState extends State<DashboardSuperAdmin> {
  bool _isLoading = true;
  double _receptionTotalHoy = 0.0;
  double _staffTotalHoy = 0.0;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, Map<String, dynamic>> _branchKPIs = {};
  List<double> _weeklyChartPersonalValues = [];
  List<double> _weeklyChartReceptionValues = [];
  List<String> _weeklyChartLabels = [];
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _criticalProducts = [];
  List<double> _weeklyVisitsValues = [];
  List<UserVisitStats> _userVisitsList = [];
  int _guestVisitsCount = 0;
  int _totalVisitsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchFinanceSummary();
  }

  Future<void> _fetchFinanceSummary() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final session = Provider.of<SessionProvider>(context, listen: false);
    if (session.userId == 'demo-super-admin-id') {
      setState(() {
        _receptionTotalHoy = 9480.0;
        _staffTotalHoy = 5620.0;
        _appointments = [
          {
            'horaInicio': '09:00',
            'clientes': {
              'nombre': 'Carlos Mendoza',
              'telefono': '5512345678',
              'correo': 'carlos@mail.com',
            },
            'Services': {
              'nameService': 'Corte Clásico + Barba',
              'tiempo_servicio': 45,
            },
            'Personal': {'nombre': 'Marcos Barber'},
            'precioFinal': 350.0,
            'completada': true,
            'estatus': 'Completada',
          },
          {
            'horaInicio': '10:30',
            'clientes': {
              'nombre': 'Ana Gómez',
              'telefono': '5587654321',
              'correo': 'ana@mail.com',
            },
            'Services': {
              'nameService': 'Tinte + Tratamiento Capilar',
              'tiempo_servicio': 90,
            },
            'Personal': {'nombre': 'Elena Stylist'},
            'precioFinal': 1200.0,
            'completada': true,
            'estatus': 'Completada',
          },
          {
            'horaInicio': '13:00',
            'clientes': {
              'nombre': 'Luis Ramírez',
              'telefono': '5533445566',
              'correo': 'luis@mail.com',
            },
            'Services': {
              'nameService': 'Corte Moderno Fade',
              'tiempo_servicio': 30,
            },
            'Personal': {'nombre': 'Marcos Barber'},
            'precioFinal': 280.0,
            'completada': false,
            'estatus': 'Pendiente',
          },
        ];
        _branchKPIs = {
          'Sucursal Polanco': {
            'id': 'polanco',
            'reception': 4850.0,
            'personal': 3200.0,
          },
          'Sucursal Condesa': {
            'id': 'condesa',
            'reception': 4630.0,
            'personal': 2420.0,
          },
        };
        _weeklyChartPersonalValues = [
          4000.0,
          5000.0,
          3500.0,
          6000.0,
          4400.0,
          6800.0,
          5100.0,
        ];
        _weeklyChartReceptionValues = [
          8000.0,
          9500.0,
          7500.0,
          9000.0,
          9000.0,
          10000.0,
          10000.0,
        ];
        _weeklyChartLabels = [
          '09/06',
          '10/06',
          '11/06',
          '12/06',
          '13/06',
          '14/06',
          '15/06',
        ];
        _staffList = [
          {
            'userID': 'demo-personal-id',
            'nombre': 'Marcos Barber',
            'TipoPersonal': 'Barbero',
            'foto_perfil': '',
            'mostrar_foto': false,
            'sucursal': 'Sucursal Polanco',
          },
          {
            'userID': 'demo-elena-id',
            'nombre': 'Elena Stylist',
            'TipoPersonal': 'Estilista',
            'foto_perfil': '',
            'mostrar_foto': false,
            'sucursal': 'Sucursal Condesa',
          },
        ];
        _criticalProducts = [
          {'nombre': 'Gel Fijador Total', 'stock': 2},
          {'nombre': 'Shampoo Anticaspa', 'stock': 3},
          {'nombre': 'Cera Moldeadora', 'stock': 5},
        ];
        _weeklyVisitsValues = [45.0, 52.0, 39.0, 61.0, 70.0, 85.0, 92.0];
        _guestVisitsCount = 120;
        _totalVisitsCount = 444;
        _isLoading = false;
      });
      return;
    }

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      final queryStart = startOfWeek.isBefore(startOfMonth)
          ? startOfWeek
          : startOfMonth;
      final queryStartStr = queryStart.toUtc().toIso8601String();
      final endOfTodayStr = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
        999,
      ).toUtc().toIso8601String();
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(now);

      Future<List<Map<String, dynamic>>> fetchVisitsSafely() async {
        try {
          final res = await Supabase.instance.client
              .from('EventosAPI')
              .select('created_at')
              .eq('tipodeevento', 'visita')
              .gte('created_at', queryStartStr)
              .lte('created_at', endOfTodayStr);
          return List<Map<String, dynamic>>.from(res);
        } catch (e) {
          debugPrint('Error loading visits safely: $e');
          return [];
        }
      }

      // Realizar las consultas de Supabase en paralelo para optimizar la velocidad de carga
      final futures = await Future.wait([
        // 0. Sucursales
        Supabase.instance.client
            .from('Sucursales')
            .select('IDSucursal, NombreSucursal')
            .eq('IDGeneral', 'FRFROIJNU821')
            .neq('NombreSucursal', 'Omar´s Barber - Sucursal Canarios')
            .neq('NombreSucursal', 'Omar´s Barber - Sucursal florida')
            .order('NombreSucursal', ascending: true),
        // 1. FinanzasPersonal del mes actual (y últimos 7 días)
        Supabase.instance.client
            .from('FinanzasPersonal')
            .select('total, QuienRegistro, sucursal, sucursal_id, fecha')
            .gte('fecha', queryStartStr)
            .lte('fecha', endOfTodayStr),
        // 2. OrdenesProductos del mes actual (y últimos 7 días)
        Supabase.instance.client
            .from('OrdenesProductos')
            .select('suma_productos, QuienRegistro, fecha')
            .gte('fecha', queryStartStr)
            .lte('fecha', endOfTodayStr),
        // 3. Citas de hoy (plain select, FK joins done in-memory below)
        Supabase.instance.client
            .from('Citas')
            .select()
            .eq('fecha', dateStr)
            .order('horaInicio', ascending: true),
        // 4. Todo el personal
        Supabase.instance.client
            .from('Personal')
            .select(
              'userID, nombre, TipoPersonal, foto_perfil, mostrar_foto, sucursal',
            )
            .order('nombre', ascending: true),
        // 5. Productos para inventario crítico
        Supabase.instance.client
            .from('Productos')
            .select('nombre, stock')
            .order('stock', ascending: true)
            .limit(5),
        // 6. Visitas y Recurrencia
        fetchVisitsSafely(),
      ]);

      final branchesList = List<Map<String, dynamic>>.from(futures[0]);
      final listFinanzas = List<Map<String, dynamic>>.from(futures[1]);
      final listOrdenes = List<Map<String, dynamic>>.from(futures[2]);
      final rawAppts = List<Map<String, dynamic>>.from(futures[3]);
      final staffRaw = List<Map<String, dynamic>>.from(futures[4]);
      final criticalProdsRaw = List<Map<String, dynamic>>.from(futures[5]);
      final visitsRaw = List<Map<String, dynamic>>.from(futures[6]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cargados: Finanzas=${listFinanzas.length}, Ordenes=${listOrdenes.length}, Citas=${rawAppts.length}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // --- In-memory join for Citas ---
      List<Map<String, dynamic>> appointmentsList = rawAppts;
      if (rawAppts.isNotEmpty) {
        final clientIds = rawAppts
            .map((a) => a['clienteID']?.toString())
            .where((id) => id != null && id!.isNotEmpty)
            .toSet()
            .cast<String>()
            .toList();
        final serviceIds = rawAppts
            .map((a) => a['servicioID']?.toString())
            .where((id) => id != null && id!.isNotEmpty)
            .toSet()
            .cast<String>()
            .toList();
        final barberIds = rawAppts
            .map((a) => a['barberoID']?.toString())
            .where((id) => id != null && id!.isNotEmpty)
            .toSet()
            .cast<String>()
            .toList();

        final clientsResp = clientIds.isEmpty
            ? []
            : await Supabase.instance.client
                  .from('clientes')
                  .select('IDCliente, nombre, telefono, correo')
                  .inFilter('IDCliente', clientIds);
        final servicesResp = serviceIds.isEmpty
            ? []
            : await Supabase.instance.client
                  .from('Services')
                  .select('id, nameService, tiempo_servicio')
                  .inFilter('id', serviceIds);
        final barbersResp = barberIds.isEmpty
            ? []
            : await Supabase.instance.client
                  .from('Personal')
                  .select('userID, nombre')
                  .inFilter('userID', barberIds);

        final clients = List<Map<String, dynamic>>.from(clientsResp);
        final services = List<Map<String, dynamic>>.from(servicesResp);
        final barbers = List<Map<String, dynamic>>.from(barbersResp);

        appointmentsList = rawAppts.map((appt) {
          final cId = appt['clienteID']?.toString();
          final sId = appt['servicioID']?.toString();
          final bId = appt['barberoID']?.toString();
          return {
            ...appt,
            'clientes': clients.firstWhere(
              (c) => c['IDCliente']?.toString() == cId,
              orElse: () => {},
            ),
            'Services': services.firstWhere(
              (s) => s['id']?.toString() == sId,
              orElse: () => {},
            ),
            'Personal': barbers.firstWhere(
              (b) => b['userID']?.toString() == bId,
              orElse: () => {},
            ),
          };
        }).toList();
      }

      // Filtrar el personal para excluir recepcionistas y administradores (solo queremos estilistas, barberos, coloristas, etc.)
      final staffFiltered = staffRaw.where((p) {
        final tipo = (p['TipoPersonal'] ?? '').toString().toLowerCase();
        return tipo != 'recepcionista' &&
            tipo != 'recepcion' &&
            tipo != 'administrador' &&
            tipo != 'gestor';
      }).toList();

      double receptionSumHoy = 0.0;
      double staffSumHoy = 0.0;

      final todayStr = intl.DateFormat('yyyy-MM-dd').format(now);
      final todayUtcStr = intl.DateFormat('yyyy-MM-dd').format(now.toUtc());

      // Inicializar el mapa de KPIs con las sucursales
      final Map<String, Map<String, dynamic>> tempKPIs = {};
      for (final b in branchesList) {
        final name = b['NombreSucursal']?.toString();
        final id = b['IDSucursal']?.toString();
        if (name != null) {
          tempKPIs[name] = {'id': id, 'reception': 0.0, 'personal': 0.0};
        }
      }

      // Sumar registros del mes actual y de hoy de FinanzasPersonal
      for (final row in listFinanzas) {
        if (row['fecha'] == null) continue;
        try {
          final fechaStr = row['fecha'].toString();
          final dt = parseDateSafely(fechaStr)?.toLocal();
          if (dt == null) continue;
          final totalVal =
              double.tryParse((row['total'] ?? 0).toString()) ?? 0.0;
          final who = row['QuienRegistro']?.toString().toLowerCase();
          final branchName = row['sucursal']?.toString();
          final branchId = row['sucursal_id']?.toString();

          // Filtro mensual
          if (dt.year == now.year && dt.month == now.month) {
            String? targetBranchName;
            if (branchId != null) {
              final found = branchesList.firstWhere(
                (b) => b['IDSucursal']?.toString() == branchId,
                orElse: () => <String, dynamic>{},
              );
              targetBranchName = found['NombreSucursal']?.toString();
            }
            targetBranchName ??= branchName;

            if (targetBranchName != null && targetBranchName.isNotEmpty) {
              tempKPIs.putIfAbsent(
                targetBranchName,
                () => {'id': branchId, 'reception': 0.0, 'personal': 0.0},
              );
              if (tempKPIs[targetBranchName]!['id'] == null &&
                  branchId != null) {
                tempKPIs[targetBranchName]!['id'] = branchId;
              }
              if (who == 'recepcion') {
                tempKPIs[targetBranchName]!['reception'] =
                    (tempKPIs[targetBranchName]!['reception'] ?? 0.0) +
                    totalVal;
              } else if (who == 'personal') {
                tempKPIs[targetBranchName]!['personal'] =
                    (tempKPIs[targetBranchName]!['personal'] ?? 0.0) + totalVal;
              }
            }
          }

          // Filtro diario
          final formatted = intl.DateFormat('yyyy-MM-dd').format(dt);
          if (formatted == todayStr ||
              fechaStr.startsWith(todayStr) ||
              fechaStr.startsWith(todayUtcStr)) {
            if (who == 'recepcion') {
              receptionSumHoy += totalVal;
            } else if (who == 'personal') {
              staffSumHoy += totalVal;
            }
          }
        } catch (_) {}
      }

      // Sumar registros del mes actual y de hoy de OrdenesProductos
      for (final row in listOrdenes) {
        if (row['fecha'] == null) continue;
        try {
          final fechaStr = row['fecha'].toString();
          final dt = parseDateSafely(fechaStr)?.toLocal();
          if (dt == null) continue;
          final totalVal =
              double.tryParse((row['suma_productos'] ?? 0).toString()) ?? 0.0;
          final who = row['QuienRegistro']?.toString().toLowerCase();
          final branchName = row['sucursal']?.toString();
          final branchId = row['sucursal_id']?.toString();

          // Filtro mensual
          if (dt.year == now.year && dt.month == now.month) {
            String? targetBranchName;
            if (branchId != null) {
              final found = branchesList.firstWhere(
                (b) => b['IDSucursal']?.toString() == branchId,
                orElse: () => <String, dynamic>{},
              );
              targetBranchName = found['NombreSucursal']?.toString();
            }
            targetBranchName ??= branchName;

            if (targetBranchName != null && targetBranchName.isNotEmpty) {
              tempKPIs.putIfAbsent(
                targetBranchName,
                () => {'id': branchId, 'reception': 0.0, 'personal': 0.0},
              );
              if (tempKPIs[targetBranchName]!['id'] == null &&
                  branchId != null) {
                tempKPIs[targetBranchName]!['id'] = branchId;
              }
              if (who == 'recepcion') {
                tempKPIs[targetBranchName]!['reception'] =
                    (tempKPIs[targetBranchName]!['reception'] ?? 0.0) +
                    totalVal;
              } else if (who == 'personal') {
                tempKPIs[targetBranchName]!['personal'] =
                    (tempKPIs[targetBranchName]!['personal'] ?? 0.0) + totalVal;
              }
            }
          }

          // Filtro diario
          final formatted = intl.DateFormat('yyyy-MM-dd').format(dt);
          if (formatted == todayStr ||
              fechaStr.startsWith(todayStr) ||
              fechaStr.startsWith(todayUtcStr)) {
            if (who == 'recepcion') {
              receptionSumHoy += totalVal;
            } else if (who == 'personal') {
              staffSumHoy += totalVal;
            }
          }
        } catch (_) {}
      }

      // Agrupar los ingresos diarios para los últimos 7 días (Total, Personal y Recepción)
      final List<double> weeklyValues = [];
      final List<double> weeklyPersonalValues = [];
      final List<double> weeklyReceptionValues = [];
      final List<String> weeklyLabels = [];

      final List<DateTime> last7Days = [];
      for (int i = 6; i >= 0; i--) {
        last7Days.add(
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
        );
      }

      for (final day in last7Days) {
        double daySum = 0.0;
        double dayPersonalSum = 0.0;
        double dayReceptionSum = 0.0;

        // Sumar FinanzasPersonal (Servicios)
        for (final r in listFinanzas) {
          if (r['fecha'] == null) continue;
          try {
            final f = parseDateSafely(r['fecha'].toString())?.toLocal();
            if (f == null) continue;
            if (f.year == day.year &&
                f.month == day.month &&
                f.day == day.day) {
              final val = double.tryParse((r['total'] ?? 0).toString()) ?? 0.0;
              daySum += val;

              final who = r['QuienRegistro']?.toString().toLowerCase();
              if (who == 'recepcion') {
                dayReceptionSum += val;
              } else if (who == 'personal') {
                dayPersonalSum += val;
              }
            }
          } catch (_) {}
        }

        // Sumar OrdenesProductos (Productos)
        for (final r in listOrdenes) {
          if (r['fecha'] == null) continue;
          try {
            final f = parseDateSafely(r['fecha'].toString())?.toLocal();
            if (f == null) continue;
            if (f.year == day.year &&
                f.month == day.month &&
                f.day == day.day) {
              final val =
                  double.tryParse((r['suma_productos'] ?? 0).toString()) ?? 0.0;
              daySum += val;

              final who = r['QuienRegistro']?.toString().toLowerCase();
              if (who == 'recepcion') {
                dayReceptionSum += val;
              } else if (who == 'personal') {
                dayPersonalSum += val;
              }
            }
          } catch (_) {}
        }

        weeklyValues.add(daySum);
        weeklyPersonalValues.add(dayPersonalSum);
        weeklyReceptionValues.add(dayReceptionSum);
        weeklyLabels.add(intl.DateFormat('d/MM').format(day));
      }

      // Agrupar las visitas diarias para los últimos 7 días
      final List<double> weeklyVisitsValues = [];
      for (final day in last7Days) {
        double dayVisitsCount = 0.0;
        for (final r in visitsRaw) {
          if (r['created_at'] == null) continue;
          try {
            final f = parseDateSafely(r['created_at'].toString())?.toLocal();
            if (f == null) continue;
            if (f.year == day.year &&
                f.month == day.month &&
                f.day == day.day) {
              dayVisitsCount += 1.0;
            }
          } catch (_) {}
        }
        weeklyVisitsValues.add(dayVisitsCount);
      }

      // Procesar visitas de usuarios para recurrencia
      final Map<String, UserVisitStats> userStatsMap = {};
      int guestVisitsCount = 0;
      int totalVisitsCount = visitsRaw.length;

      for (final r in visitsRaw) {
        final rawEvento = r['evento'];
        String? userId;
        String? name;
        String? email;

        if (rawEvento is Map) {
          final visitaVal = rawEvento['visita']?.toString();
          if (visitaVal != null &&
              visitaVal != 'invitado' &&
              visitaVal != 'sinusuario') {
            userId = visitaVal;
            name = rawEvento['nombre']?.toString();
            email = rawEvento['email']?.toString();
          }
        } else if (rawEvento is String) {
          // Parse old text format, e.g. "Acceso Usuario Logueado (mike.vaz@hotmail.com)"
          if (rawEvento.contains('Acceso Usuario Logueado')) {
            final regExp = RegExp(r'\(([^)]+)\)');
            final match = regExp.firstMatch(rawEvento);
            if (match != null) {
              email = match.group(1);
              userId = email; // Fallback to email as ID
              name = email;
            }
          }
        }

        if (userId != null && userId.isNotEmpty) {
          final key = userId;
          if (userStatsMap.containsKey(key)) {
            userStatsMap[key]!.count += 1;
          } else {
            userStatsMap[key] = UserVisitStats(
              userId: userId,
              name: name ?? email ?? 'Usuario Registrado',
              email: email ?? '',
              count: 1,
            );
          }
        } else {
          guestVisitsCount += 1;
        }
      }

      final sortedUserStats = userStatsMap.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      if (mounted) {
        setState(() {
          _receptionTotalHoy = receptionSumHoy;
          _staffTotalHoy = staffSumHoy;
          _appointments = appointmentsList;
          _branchKPIs = tempKPIs;
          _weeklyChartPersonalValues = weeklyPersonalValues;
          _weeklyChartReceptionValues = weeklyReceptionValues;
          _weeklyChartLabels = weeklyLabels;
          _staffList = staffFiltered;
          _criticalProducts = criticalProdsRaw;
          _weeklyVisitsValues = weeklyVisitsValues;
          _userVisitsList = sortedUserStats;
          _guestVisitsCount = guestVisitsCount;
          _totalVisitsCount = totalVisitsCount;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint(
        'Error fetching finance/appointments summary: $e\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 7),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final dbContext = '''
=== DATOS ACTUALES DE LA BASE DE DATOS (DASHBOARD) ===
- Ingresos Recepción (Hoy): \$$_receptionTotalHoy
- Ingresos Personal (Hoy): \$$_staffTotalHoy
- Citas Totales (Hoy): ${_appointments.length}
- Citas Pendientes: ${_appointments.where((a) => a['estatus'] == 'Pendiente').length}
- Citas Completadas: ${_appointments.where((a) => a['estatus'] == 'Completada').length}
- Total de Empleados/Personal: ${_staffList.length}
- Productos con bajo stock crítico: ${_criticalProducts.length}
- Total Visitas Históricas de Clientes: $_totalVisitsCount
======================================================
''';
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AiChatScreen(dbContext: dbContext)),
          );
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
        tooltip: 'Asistente IA',
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFinanceSummary,
        color: Colors.black,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildFinanceSummaryRow(),
            const SizedBox(height: 24),
            _buildRevenueCards(),
            const SizedBox(height: 24),
            _buildSectionTitle(
              'Citas de Hoy',
              Icons.calendar_today_outlined,
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GeneralAgendaScreen(),
                    ),
                  ).then((_) => _fetchFinanceSummary());
                },
                child: const Text(
                  'Ver citas completas',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildAppointmentList(),
            const SizedBox(height: 24),
            _buildSectionTitle(
              'Ingresos de la Semana',
              Icons.trending_up,
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const FinanzasGeneralesDashboardScreen(
                            initialCajaIndex: 0,
                          ),
                    ),
                  ).then((_) => _fetchFinanceSummary());
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mostrar finanzas',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.blueAccent,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildLineChart(),
            const SizedBox(height: 24),
            _buildVisitsChartSection(),
            const SizedBox(height: 24),
            _buildPastFinancesButton(),
            const SizedBox(height: 30),
            const UniversalFooterButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ));
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Super Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vista Financiera General',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${months[now.month - 1]} ${now.year}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastFinancesButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PastFinancesScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_toggle_off_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finanzas Pasadas (Tiempo Real)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Historial completo de ingresos y movimientos',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceSummaryRow() {
    if (_isLoading) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FinanzasGeneralesDashboardScreen(
                    initialCajaIndex: 0,
                  ),
                ),
              ).then((_) => _fetchFinanceSummary());
            },
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.blueAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Caja Recepción (Hoy)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${formatMoney(_receptionTotalHoy)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FinanzasGeneralesDashboardScreen(
                    initialCajaIndex: 1,
                  ),
                ),
              ).then((_) => _fetchFinanceSummary());
            },
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt_outlined,
                      color: Colors.green,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Caja Personal (Hoy)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${formatMoney(_staffTotalHoy)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueCards() {
    final totalHoy = _receptionTotalHoy + _staffTotalHoy;
    final cards = [
      _CardData(
        label: 'Ingresos Hoy',
        value: '\$${formatMoney(totalHoy, decimalDigits: 0)}',
        icon: Icons.attach_money,
        trend: '+12%',
        up: true,
      ),
      _CardData(
        label: 'Citas Hoy',
        value: '${_appointments.length}',
        icon: Icons.calendar_today,
        trend: '+5%',
        up: true,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final card = cards[i];
        return GestureDetector(
          onTap: () {
            if (card.label == 'Citas Hoy') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GeneralAgendaScreen(),
                ),
              ).then((_) => _fetchFinanceSummary());
            } else if (card.label == 'Ingresos Hoy') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FinanzasGeneralesDashboardScreen(
                    initialCajaIndex: 0,
                  ),
                ),
              ).then((_) => _fetchFinanceSummary());
            }
          },
          child: _buildMetricCard(card),
        );
      },
    );
  }

  Widget _buildMetricCard(_CardData data) {
    final trendColor = data.up == null
        ? Colors.black38
        : (data.up! ? Colors.black87 : Colors.black54);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: Colors.black, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.trend,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                data.label,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final hasData =
        (_weeklyChartPersonalValues.isNotEmpty &&
            _weeklyChartPersonalValues.any((v) => v > 0)) ||
        (_weeklyChartReceptionValues.isNotEmpty &&
            _weeklyChartReceptionValues.any((v) => v > 0));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tendencia de ingresos (7 días)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_weeklyChartLabels.isNotEmpty) ...[
                Text(
                  _weeklyChartLabels.first,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const Text(
                  ' → ',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
                Text(
                  _weeklyChartLabels.last,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Caja Recepción',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2ECC71),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Caja Personal',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const SizedBox(
              height: 140,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white38,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (!hasData)
            const SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'Sin datos de ingresos esta semana',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: const Size(double.infinity, 140),
                painter: _LineChartPainter(
                  _weeklyChartReceptionValues,
                  values2: _weeklyChartPersonalValues,
                  labels: _weeklyChartLabels,
                  textDirection: Directionality.of(context),
                  lineColor: Colors.blueAccent,
                  lineColor2: const Color(0xFF2ECC71),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitsChartSection() {
    final hasData =
        _weeklyVisitsValues != null &&
        _weeklyVisitsValues.isNotEmpty &&
        _weeklyVisitsValues.any((v) => v > 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people_alt_outlined,
                  color: Colors.black,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Visitas de la App (7 días)',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showUserVisitsDialog,
                icon: const Icon(
                  Icons.analytics_outlined,
                  size: 16,
                  color: Colors.blueAccent,
                ),
                label: const Text(
                  'Ver usuarios',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tendencia de accesos',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    if (_weeklyChartLabels.isNotEmpty)
                      Text(
                        '${_weeklyChartLabels.first} a ${_weeklyChartLabels.last}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white38,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (!hasData)
                  const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'Sin visitas registradas esta semana',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 120,
                    child: CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _LineChartPainter(
                        _weeklyVisitsValues ?? [],
                        labels: _weeklyChartLabels,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Summary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildVisitMetric('Total', '$_totalVisitsCount', Colors.black),
              _buildVisitMetric(
                'Registrados',
                '${_totalVisitsCount - _guestVisitsCount}',
                Colors.blueAccent,
              ),
              _buildVisitMetric(
                'Invitados',
                '$_guestVisitsCount',
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  void _showUserVisitsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _UserVisitsDialogContent(
              visitsList: _userVisitsList ?? [],
              guestCount: _guestVisitsCount,
            );
          },
        );
      },
    );
  }

  Widget _buildStaffGrid() {
    if (_staffList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No hay personal activo registrado.',
            style: TextStyle(color: Colors.black38, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: _staffList.map((s) {
        final staffId = s['userID']?.toString() ?? '';
        final name = s['nombre']?.toString() ?? 'Sin Nombre';
        final role = s['TipoPersonal']?.toString() ?? 'Personal';
        final photoUrl = s['foto_perfil']?.toString();
        final mostrarFoto = s['mostrar_foto'] ?? true;
        final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

        final apptCount = _appointments
            .where((appt) => appt['barberoID']?.toString() == staffId)
            .length;
        final apptText = '$apptCount cita${apptCount != 1 ? 's' : ''}';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PersonalFinanceKpisScreen(
                  personalId: staffId,
                  personalName: name,
                  personalRole: role,
                  fotoPerfil: photoUrl,
                  mostrarFoto: mostrarFoto,
                ),
              ),
            ).then((_) => _fetchFinanceSummary());
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.08),
                  child: (hasPhoto && mostrarFoto)
                      ? ClipOval(
                          child: Image.network(
                            photoUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Text(
                              name.trim().isEmpty
                                  ? '?'
                                  : name.trim()[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          name.trim().isEmpty
                              ? '?'
                              : name.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    apptText,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInventoryList() {
    if (_criticalProducts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'No hay productos registrados',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _criticalProducts.map((p) {
          final String name = p['nombre'] ?? 'Sin nombre';
          final int stock = p['stock'] ?? 0;
          final double level = (stock / 20.0).clamp(0.0, 1.0);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$stock unidades',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: level,
                    minHeight: 6,
                    backgroundColor: Colors.black.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation(Colors.black),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Widget? trailing) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.black, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        if (trailing != null) const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildAppointmentList() {
    final pendingAppts = _appointments.where((appt) {
      final status = appt['estatus']?.toString().toLowerCase() ?? 'pendiente';
      return status == 'pendiente';
    }).toList();

    if (pendingAppts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.event_available, size: 40, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              'No hay citas pendientes para este día',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: pendingAppts
          .map((appt) => _buildAppointmentCard(appt))
          .toList(),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final clientData = appointment['clientes'] as Map<String, dynamic>? ?? {};
    final serviceData = appointment['Services'] as Map<String, dynamic>? ?? {};

    final clientName =
        clientData['nombre'] ??
        appointment['nombreClienteTemporal'] ??
        appointment['NombreCliente'] ??
        'Cliente Desconocido';
    final serviceName =
        serviceData['nameService'] ??
        appointment['nombreServicioPersonalizado'] ??
        appointment['Servicios'] ??
        'Servicio';
    final timeStart = appointment['horaInicio'] ?? '--:--';
    final rawPrice =
        appointment['precioCobrado'] ??
        appointment['precioFinal'] ??
        appointment['MontoACobrar'] ??
        0;
    final priceStr = rawPrice.toString().startsWith('\$')
        ? rawPrice.toString()
        : '\$$rawPrice';
    final isCompleted = appointment['completada'] == true;

    final statusLabel = isCompleted ? 'Completada' : 'Pendiente';
    final barberName = appointment['Personal'] is String
        ? appointment['Personal'] as String
        : appointment['Personal']?['nombre'] ?? 'Sin asignar';

    return GestureDetector(
      onTap: () => _showAppointmentDetails(context, appointment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: !isCompleted
              ? Border.all(color: Colors.black12, width: 1.5)
              : Border.all(
                  color: Colors.green.withValues(alpha: 0.2),
                  width: 1.5,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  timeStart,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 40, color: Colors.black12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    serviceName,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.face, size: 12, color: Colors.black38),
                      const SizedBox(width: 4),
                      Text(
                        'Asignado: $barberName',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceStr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: isCompleted ? Colors.green.shade800 : Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentDetails(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    final barberName = appointment['Personal'] is String
        ? appointment['Personal'] as String
        : appointment['Personal']?['nombre'] ?? 'Sin asignar';
    final serviceName =
        appointment['Servicios'] as String? ??
        appointment['notas'] as String? ??
        appointment['Services']?['nameService'] ??
        'Servicio';
    final clientName =
        appointment['NombreCliente'] as String? ??
        appointment['clientes']?['nombre'] ??
        'Cliente';
    final clientEmail =
        appointment['CorreoCliente'] as String? ??
        appointment['clientes']?['correo'] ??
        'Sin correo';
    final clientPhone =
        appointment['NumeroTelefonoC'] as String? ??
        appointment['clientes']?['telefono'] ??
        'Sin teléfono';
    final branch =
        appointment['Sucursal'] as String? ??
        appointment['sucursal'] as String? ??
        'General';
    final price =
        appointment['MontoACobrar'] ??
        appointment['precioFinal'] ??
        appointment['precioCobrado'] ??
        0;

    final date = appointment['fecha'] ?? '';
    final time = (appointment['horaInicio'] ?? '').toString().length >= 5
        ? (appointment['horaInicio'] as String).substring(0, 5)
        : appointment['horaInicio'] ?? '';
    final status = appointment['estatus'] ?? 'Pendiente';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        Color badgeColor;
        switch (status.toLowerCase()) {
          case 'confirmada':
          case 'activa':
            badgeColor = Colors.green;
            break;
          case 'completada':
            badgeColor = Colors.blue;
            break;
          case 'cancelada':
            badgeColor = Colors.red;
            break;
          default:
            badgeColor = Colors.orange;
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detalles de la Cita',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.black54),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              _buildDetailItem(Icons.person_outline, 'Cliente', clientName),
              _buildDetailItem(
                Icons.phone_outlined,
                'Teléfono del Cliente',
                clientPhone,
              ),
              _buildDetailItem(
                Icons.mail_outline,
                'Correo del Cliente',
                clientEmail,
              ),
              _buildDetailItem(Icons.content_cut, 'Servicio(s)', serviceName),
              _buildDetailItem(Icons.storefront_outlined, 'Sucursal', branch),
              _buildDetailItem(Icons.face, 'Personal Asignado', barberName),
              _buildDetailItem(Icons.calendar_today_outlined, 'Fecha', date),
              _buildDetailItem(Icons.access_time, 'Hora', time),
              _buildDetailItem(
                Icons.attach_money,
                'Monto a Cobrar',
                '\$$price',
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estatus',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchKPIsList() {
    if (_branchKPIs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'No hay sucursales registradas o datos de hoy',
            style: TextStyle(color: Colors.black38, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: _branchKPIs.entries.map((entry) {
        final branchName = entry.key;
        final branchId = entry.value['id']?.toString();
        final receptionSum = entry.value['reception'] ?? 0.0;
        final staffSum = entry.value['personal'] ?? 0.0;
        final totalSum = receptionSum + staffSum;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FinanzasSucursalDashboardScreen(
                      branchName: branchName,
                      branchId: branchId,
                      initialCajaIndex: 0,
                    ),
                  ),
                ).then((_) => _fetchFinanceSummary());
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              branchName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Total: \$${formatMoney(totalSum)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FinanzasSucursalDashboardScreen(
                                        branchName: branchName,
                                        branchId: branchId,
                                        initialCajaIndex: 0,
                                      ),
                                ),
                              ).then((_) => _fetchFinanceSummary());
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Recepción',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        '\$${formatMoney(receptionSum)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FinanzasSucursalDashboardScreen(
                                        branchName: branchName,
                                        branchId: branchId,
                                        initialCajaIndex: 1,
                                      ),
                                ),
                              ).then((_) => _fetchFinanceSummary());
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Personal',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        '\$${formatMoney(staffSum)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Data models
class _CardData {
  final String label, value, trend;
  final IconData icon;
  final bool? up;
  const _CardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.trend,
    required this.up,
  });
}

// Chart Painter
class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<double>? values2;
  final List<String> labels;
  final TextDirection textDirection;
  final Color lineColor;
  final Color? lineColor2;

  _LineChartPainter(
    this.values, {
    this.values2,
    required this.labels,
    required this.textDirection,
    this.lineColor = Colors.white,
    this.lineColor2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty && (values2 == null || values2!.isEmpty)) return;

    double maxVal = 0.0;
    if (values.isNotEmpty) {
      maxVal = values.reduce((a, b) => a > b ? a : b);
    }
    if (values2 != null && values2!.isNotEmpty) {
      final max2 = values2!.reduce((a, b) => a > b ? a : b);
      if (max2 > maxVal) maxVal = max2;
    }

    final n = values.isNotEmpty ? values.length : (values2?.length ?? 0);

    void drawSingleLine(
      List<double> lineValues,
      Color color, {
      bool drawGradient = true,
    }) {
      if (lineValues.isEmpty) return;
      final len = lineValues.length;
      List<Offset> points = [];
      for (var i = 0; i < len; i++) {
        final x = len == 1 ? size.width / 2 : (i / (len - 1)) * size.width;
        final y = maxVal > 0
            ? size.height - 20 - (lineValues[i] / maxVal) * (size.height - 40)
            : size.height - 20;
        points.add(Offset(x, y));
      }

      // --- Gradiente de relleno bajo la línea ---
      if (drawGradient && points.length > 1) {
        final fillPath = Path();
        fillPath.moveTo(points.first.dx, size.height - 20);
        fillPath.lineTo(points.first.dx, points.first.dy);
        for (var i = 1; i < points.length; i++) {
          final prev = points[i - 1];
          final curr = points[i];
          final cpX = (prev.dx + curr.dx) / 2;
          fillPath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
        }
        fillPath.lineTo(points.last.dx, size.height - 20);
        fillPath.lineTo(points.first.dx, size.height - 20);

        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        final gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
        );
        final fillPaint = Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.fill;
        canvas.drawPath(fillPath, fillPaint);
      }

      // --- Línea principal ---
      if (points.length > 1) {
        final linePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final linePath = Path();
        linePath.moveTo(points.first.dx, points.first.dy);
        for (var i = 1; i < points.length; i++) {
          final prev = points[i - 1];
          final curr = points[i];
          final cpX = (prev.dx + curr.dx) / 2;
          linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
        }
        canvas.drawPath(linePath, linePaint);
      }

      // --- Puntos en cada día ---
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final dotBorderPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      for (final p in points) {
        canvas.drawCircle(p, 5, dotBorderPaint);
        canvas.drawCircle(p, 3, dotPaint);
      }
    }

    // Dibujar primera línea
    drawSingleLine(values, lineColor, drawGradient: values2 == null);

    // Dibujar segunda línea
    if (values2 != null && values2!.isNotEmpty && lineColor2 != null) {
      drawSingleLine(values2!, lineColor2!, drawGradient: false);
    }

    // --- Etiquetas de fecha (sólo primera y última) ---
    final labelStyle = TextStyle(
      color: Colors.white60,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    void drawLabel(String text, double x, {bool rightAlign = false}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: textDirection,
      );
      tp.layout();
      double dx = x - (rightAlign ? tp.width : 0);
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - 16));
    }

    if (n >= 1 && labels.isNotEmpty) {
      drawLabel(labels.first, 0);
    }
    if (n >= 2 && labels.length >= 2) {
      drawLabel(labels.last, size.width, rightAlign: true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class UserVisitStats {
  final String userId;
  final String name;
  final String email;
  int count;

  UserVisitStats({
    required this.userId,
    required this.name,
    required this.email,
    required this.count,
  });
}

class _UserVisitsDialogContent extends StatefulWidget {
  final List<UserVisitStats> visitsList;
  final int guestCount;

  const _UserVisitsDialogContent({
    required this.visitsList,
    required this.guestCount,
  });

  @override
  State<_UserVisitsDialogContent> createState() =>
      _UserVisitsDialogContentState();
}

class _UserVisitsDialogContentState extends State<_UserVisitsDialogContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.visitsList.where((u) {
      final query = _searchQuery.toLowerCase();
      final name = u.name.toLowerCase();
      final email = u.email.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: Colors.black,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Frecuencia de Visitas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Search input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar usuario por nombre o correo...',
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black87),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              // List of users
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No hay visitas de usuarios registrados'
                              : 'No se encontraron coincidencias',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final user = filteredList[index];
                          final initial = user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : (user.email.isNotEmpty
                                    ? user.email[0].toUpperCase()
                                    : 'U');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.black87,
                                  radius: 18,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (user.email.isNotEmpty &&
                                          user.email != user.name) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${user.count} ${user.count == 1 ? "visita" : "visitas"}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (widget.guestCount > 0 && _searchQuery.isEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: Colors.black12),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Visitas de Invitados (sin cuenta):',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${widget.guestCount} visitas',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

DateTime? parseDateSafely(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;
  try {
    String cleaned = dateStr.replaceAll(' ', 'T');
    if (cleaned.contains('+') && !cleaned.contains(':', cleaned.indexOf('+'))) {
      cleaned = '$cleaned:00';
    } else if (cleaned.contains('-') &&
        cleaned.indexOf('-') > 10 &&
        !cleaned.contains(':', cleaned.indexOf('-'))) {
      cleaned = '$cleaned:00';
    }
    return DateTime.parse(cleaned);
  } catch (e) {
    debugPrint('Error parsing date "$dateStr": $e');
    return null;
  }
}
