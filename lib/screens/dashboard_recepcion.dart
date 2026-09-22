import 'package:flutter/material.dart';
import 'package:totalpro/utils/formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/session_provider.dart';
import '../services/email_service.dart';
import '../widgets/universal_footer_buttons.dart';
import 'general_agenda_screen.dart';
import 'finanzas_recepcion_dashboard_screen.dart';

class DashboardRecepcion extends StatefulWidget {
  const DashboardRecepcion({super.key});

  @override
  State<DashboardRecepcion> createState() => _DashboardRecepcionState();
}

class _DashboardRecepcionState extends State<DashboardRecepcion> {
  bool _isLoading = true;
  String? _staffId;
  String _staffName = 'Recepción';

  List<Map<String, dynamic>> _assignedInventory = [];
  bool _loadingInventory = true;

  int _dayOffset = 0; // 0 = Hoy, 1 = Mañana, 2 = Pasado Mañana
  List<Map<String, dynamic>> _appointments = [];

  // Summary stats
  double _finanzasGralHoy = 0.0;
  double _finanzasProdHoy = 0.0;

  @override
  void initState() {
    super.initState();
    _initStaffData();
  }

  Future<void> _initStaffData() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      if (session.userId == 'demo-recepcion-id') {
        setState(() {
          _staffId = 'demo-recepcion-id';
          _staffName = 'Demo Recepción';
          _finanzasGralHoy = 4850.0;
          _finanzasProdHoy = 1200.0;
          _assignedInventory = [
            {'name': 'Shampoo Premium 500ml', 'qty': 5},
            {'name': 'Cera Moldeadora Total', 'qty': 8},
            {'name': 'Aceite de Argán 100ml', 'qty': 3},
          ];
          _loadingInventory = false;
        });
        await _fetchAppointmentsForOffset();
        return;
      }

      if (session.userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final personalData = await Supabase.instance.client
          .from('Personal')
          .select('nombre')
          .eq('userID', session.userId!)
          .maybeSingle();

      if (personalData != null) {
        _staffId = session.userId;
        _staffName = personalData['nombre'] ?? 'Recepción';
      } else {
        _staffId = null;
        _staffName = 'Recepción';
      }
      await _fetchSummaryStats();
      await _fetchAppointmentsForOffset();
      await _loadAssignedInventory();
    } catch (e) {
      debugPrint('Error initStaffData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAssignedInventory() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final userId = _staffId ?? session.userId;
    if (userId == null) {
      if (mounted) setState(() => _loadingInventory = false);
      return;
    }

    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await Supabase.instance.client
          .from('InventarioDiario')
          .select('nombre_producto, stock, asignacion_personal')
          .eq('fecha', todayStr);

      final list = List<Map<String, dynamic>>.from(response);
      List<Map<String, dynamic>> temp = [];

      for (final item in list) {
        final asignaciones = item['asignacion_personal'];
        if (asignaciones is List) {
          for (final a in asignaciones) {
            if (a is Map && a['personal_id'] == userId) {
              final qty = int.tryParse(a['cantidad'].toString()) ?? 0;
              temp.add({
                'name': item['nombre_producto'] ?? 'Producto',
                'qty': qty,
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _assignedInventory = temp;
          _loadingInventory = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading assigned inventory: $e');
      if (mounted) {
        setState(() => _loadingInventory = false);
      }
    }
  }

  Future<void> _fetchSummaryStats() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final userId = _staffId ?? session.userId;
      if (userId == null) return;

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc().toIso8601String();

      // Consultar Finanzas Gral de hoy
      final finanzasGralResp = await Supabase.instance.client
          .from('FinanzasPersonal')
          .select('total')
          .ilike('QuienRegistro', 'recepcion')
          .gte('fecha', startOfToday)
          .lte('fecha', endOfToday);

      double sumGral = 0.0;
      for (var row in finanzasGralResp) {
        sumGral += double.tryParse((row['total'] ?? 0).toString()) ?? 0.0;
      }

      // Consultar OrdenesProductos de hoy
      final ordenesResponse = await Supabase.instance.client
          .from('OrdenesProductos')
          .select('suma_productos')
          .ilike('QuienRegistro', 'recepcion')
          .gte('fecha', startOfToday)
          .lte('fecha', endOfToday);

      double sumProd = 0.0;
      for (var row in ordenesResponse) {
        sumProd += double.tryParse((row['suma_productos'] ?? 0).toString()) ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _finanzasGralHoy = sumGral;
          _finanzasProdHoy = sumProd;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  Future<void> _fetchAppointmentsForOffset() async {
    setState(() => _isLoading = true);

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      if (session.userId == 'demo-recepcion-id') {
        setState(() {
          _appointments = [
            {
              'horaInicio': '09:00',
              'clientes': {'nombre': 'Carlos Mendoza', 'telefono': '5512345678', 'correo': 'carlos@mail.com'},
              'Services': {'nameService': 'Corte Clásico + Barba', 'tiempo_servicio': 45},
              'Personal': {'nombre': 'Marcos Barber'},
              'precioCobrado': 350.0,
              'completada': true,
              'estatus': 'Completada',
            },
            {
              'horaInicio': '10:30',
              'clientes': {'nombre': 'Ana Gómez', 'telefono': '5587654321', 'correo': 'ana@mail.com'},
              'Services': {'nameService': 'Tinte + Tratamiento Capilar', 'tiempo_servicio': 90},
              'Personal': {'nombre': 'Elena Stylist'},
              'precioCobrado': 1200.0,
              'completada': false,
              'estatus': 'Confirmada',
            },
            {
              'horaInicio': '13:00',
              'clientes': {'nombre': 'Luis Ramírez', 'telefono': '5533445566', 'correo': 'luis@mail.com'},
              'Services': {'nameService': 'Corte Moderno Fade', 'tiempo_servicio': 30},
              'Personal': {'nombre': 'Marcos Barber'},
              'precioCobrado': 280.0,
              'completada': false,
              'estatus': 'Pendiente',
            },
          ];
          _isLoading = false;
        });
        return;
      }

      final targetDate = DateTime.now().add(Duration(days: _dayOffset));
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      final response = await Supabase.instance.client
          .from('Citas')
          .select()
          .eq('fecha', dateStr)
          .order('horaInicio', ascending: true);

      final appts = List<Map<String, dynamic>>.from(response);

      if (appts.isEmpty) {
        if (mounted) {
          setState(() {
            _appointments = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Extract unique IDs for joins
      final clientIds = appts
          .map((a) => a['clienteID']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final barberIds = appts
          .map((a) => a['barberoID']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final serviceIds = appts
          .map((a) => a['servicioID']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      // Fetch client details
      List<Map<String, dynamic>> clients = [];
      if (clientIds.isNotEmpty) {
        final clientResp = await Supabase.instance.client
            .from('clientes')
            .select('IDCliente, nombre, telefono, correo')
            .inFilter('IDCliente', clientIds);
        clients = List<Map<String, dynamic>>.from(clientResp);
      }

      // Fetch barber details
      List<Map<String, dynamic>> barbers = [];
      if (barberIds.isNotEmpty) {
        final barbResp = await Supabase.instance.client
            .from('Personal')
            .select('userID, nombre')
            .inFilter('userID', barberIds);
        barbers = List<Map<String, dynamic>>.from(barbResp);
      }

      // Fetch service details
      List<Map<String, dynamic>> services = [];
      if (serviceIds.isNotEmpty) {
        final servResp = await Supabase.instance.client
            .from('Services')
            .select('id, nameService, tiempo_servicio')
            .inFilter('id', serviceIds);
        services = List<Map<String, dynamic>>.from(servResp);
      }

      // Join in memory
      final joined = appts.map((appt) {
        final cId = appt['clienteID']?.toString();
        final bId = appt['barberoID']?.toString();
        final sId = appt['servicioID']?.toString();

        final client = clients.firstWhere(
          (c) => c['IDCliente']?.toString() == cId,
          orElse: () => <String, dynamic>{'nombre': 'Sin nombre'},
        );

        final barber = barbers.firstWhere(
          (b) => b['userID']?.toString() == bId,
          orElse: () => <String, dynamic>{'nombre': 'Sin asignar'},
        );

        final service = services.firstWhere(
          (s) => s['id']?.toString() == sId,
          orElse: () => <String, dynamic>{'nameService': 'Servicio', 'tiempo_servicio': 30},
        );

        return {
          ...appt,
          'clientes': client,
          'Personal': barber,
          'Services': service,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _appointments = joined;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onDaySelected(int offset) {
    setState(() {
      _dayOffset = offset;
    });
    _fetchAppointmentsForOffset();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _staffId != null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchSummaryStats();
        await _fetchAppointmentsForOffset();
      },
      color: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 160,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(
                  'Tus citas',
                  Icons.event_note_outlined,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GeneralAgendaScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Ver citas completas',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDaySelector(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              )
            else
              _buildAppointmentList(),
            const SizedBox(height: 24),
            _buildSectionTitle(
              'Inventario Asignado',
              Icons.inventory_2_outlined,
            ),
            const SizedBox(height: 12),
            _buildInventoryMini(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tus finanzas de hoy',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FinanzasRecepcionDashboardScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Ver finanzas completas',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: () {
                final session = Provider.of<SessionProvider>(context, listen: false);
                if (session.userId == 'demo-recepcion-id') {
                  return Future.value([
                    {
                      'fecha': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
                      'sucursal': 'Sucursal Polanco',
                      'total': 350.0,
                      'Gasto': null,
                    },
                    {
                      'fecha': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
                      'sucursal': 'Sucursal Polanco',
                      'total': null,
                      'Gasto': '150.0',
                    },
                    {
                      'fecha': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
                      'sucursal': 'Sucursal Polanco',
                      'total': 1200.0,
                      'Gasto': null,
                    },
                  ]);
                }
                final now = DateTime.now();
                final startOfToday = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
                final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc().toIso8601String();
                return Supabase.instance.client
                    .from('FinanzasPersonal')
                    .select()
                    .eq('QuienRegistro', 'recepcion')
                    .gte('fecha', startOfToday)
                    .lte('fecha', endOfToday)
                    .order('fecha', ascending: false)
                    .limit(8);
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rows = List<dynamic>.from(snapshot.data ?? []);
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No hay registros recientes'),
                  );
                }
                return Column(
                  children: rows.map((r) {
                    final fecha = r['fecha'] != null
                        ? DateTime.parse(r['fecha'])
                        : null;
                    final gastoVal = r['Gasto'];
                    final isGasto = gastoVal != null && gastoVal.toString().trim().isNotEmpty;
                    final displayAmt = isGasto ? gastoVal.toString() : (r['total'] ?? 0).toString();
                    
                    final double parsedAmt = double.tryParse(displayAmt) ?? 0.0;
                    final formattedAmt = parsedAmt % 1 == 0 ? parsedAmt.toInt().toString() : formatMoney(parsedAmt);

                    return ListTile(
                      dense: true,
                      title: Text(
                        fecha != null
                            ? DateFormat('yyyy-MM-dd HH:mm').format(fecha)
                            : 'Sin fecha',
                      ),
                      subtitle: Text(
                        isGasto ? '${r['sucursal'] ?? ''} • Gasto' : (r['sucursal'] ?? ''),
                        style: TextStyle(
                          color: isGasto ? Colors.red.withOpacity(0.8) : Colors.black54,
                          fontWeight: isGasto ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        isGasto ? '-\$$formattedAmt' : '\$$formattedAmt',
                        style: TextStyle(
                          color: isGasto ? Colors.red : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FinanzasRecepcionDashboardScreen(),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 30),
            const UniversalFooterButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : (hour < 18 ? 'Buenas tardes' : 'Buenas noches');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.support_agent,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _staffName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            greeting,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tus registros del día de hoy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINANZAS GENERAL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${formatMoney(_finanzasGralHoy)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withOpacity(0.15),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'VENTA PRODUCTOS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${formatMoney(_finanzasProdHoy)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Row(
      children: [
        _buildDayBtn(0, 'Hoy'),
        const SizedBox(width: 8),
        _buildDayBtn(1, 'Mañana'),
        const SizedBox(width: 8),
        _buildDayBtn(2, 'Pasado'),
      ],
    );
  }

  Widget _buildDayBtn(int offset, String label) {
    final isSelected = _dayOffset == offset;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onDaySelected(offset),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
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
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
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
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: !isCompleted
              ? Border.all(color: Colors.black12, width: 1.5)
              : Border.all(color: Colors.green.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                        style: const TextStyle(color: Colors.black45, fontSize: 11),
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
                        ? Colors.green.shade100
                        : Colors.black.withOpacity(0.07),
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
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: badgeColor == Colors.green
                            ? Colors.green.shade700
                            : (badgeColor == Colors.blue
                                ? Colors.blue.shade700
                                : (badgeColor == Colors.red
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700)),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (status.toLowerCase() != 'cancelada' && status.toLowerCase() != 'completada') ...[
                const SizedBox(height: 24),
                if (status.toLowerCase() == 'pendiente') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmAppointmentDialog(context, appointment),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'Confirmar Cita',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmCancelAppointment(context, appointment),
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text(
                      'Cancelar Cita',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryMini() {
    if (_loadingInventory) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10),
          ],
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (_assignedInventory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10),
          ],
        ),
        child: const Center(
          child: Text(
            'No tienes inventario asignado para hoy.',
            style: TextStyle(color: Colors.black38, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10),
        ],
      ),
      child: Column(
        children: _assignedInventory.map((item) {
          final qty = item['qty'] as int;
          final name = item['name'] as String;

          final isAlert = qty <= 2;
          final status = qty == 0 ? 'Agotado' : (qty <= 2 ? 'Bajo stock' : 'Stock OK');
          final icon = qty == 0 
              ? Icons.error_outline 
              : (qty <= 2 ? Icons.warning_amber_outlined : Icons.check_circle_outline);
          final statusColor = qty == 0 
              ? Colors.red 
              : (qty <= 2 ? Colors.orange.shade800 : Colors.black38);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isAlert ? Colors.black : Colors.black45,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '$status ($qty)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.07),
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
      ],
    );
  }

  void _confirmAppointmentDialog(BuildContext context, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Cita'),
          content: const Text('¿Estás seguro de que deseas confirmar esta cita?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Cerrar diálogo
                Navigator.pop(context); // Cerrar modal de detalles
                _confirmAppointment(appointment);
              },
              child: const Text('Confirmar', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAppointment(Map<String, dynamic> appointment) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('Citas')
          .update({'estatus': 'Confirmada'})
          .eq('clienteID', appointment['clienteID'])
          .eq('barberoID', appointment['barberoID'])
          .eq('servicioID', appointment['servicioID'])
          .eq('fecha', appointment['fecha'])
          .eq('horaInicio', appointment['horaInicio']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita confirmada correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _fetchAppointmentsForOffset();
      await _fetchSummaryStats();
    } catch (e) {
      debugPrint('Error confirming appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al confirmar la cita: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmCancelAppointment(BuildContext context, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Cancelación'),
          content: const Text('¿Estás seguro de que deseas cancelar esta cita? Esta acción no se puede deshacer y se enviará una notificación por correo al cliente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Atrás', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Cerrar diálogo
                Navigator.pop(context); // Cerrar modal de detalles
                _cancelAppointment(appointment);
              },
              child: const Text('Confirmar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('Citas')
          .update({'estatus': 'Cancelada'})
          .eq('clienteID', appointment['clienteID'])
          .eq('barberoID', appointment['barberoID'])
          .eq('servicioID', appointment['servicioID'])
          .eq('fecha', appointment['fecha'])
          .eq('horaInicio', appointment['horaInicio']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita cancelada correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _fetchAppointmentsForOffset();
      await _fetchSummaryStats();

      final clientData = appointment['clientes'] as Map<String, dynamic>?;
      final clientEmail = clientData?['correo'] as String? ?? appointment['CorreoCliente'] as String?;
      if (clientEmail != null && clientEmail.trim().isNotEmpty) {
        final clientName = clientData?['nombre'] as String? ?? appointment['NombreCliente'] as String? ?? 'Cliente';
        
        final serviceData = appointment['Services'] as Map<String, dynamic>?;
        final serviceName = serviceData?['nameService'] as String? 
            ?? appointment['Servicios'] as String? 
            ?? appointment['notas'] as String? 
            ?? 'Servicio';
            
        final barberData = appointment['Personal'] as Map<String, dynamic>?;
        final barberName = barberData?['nombre'] as String? 
            ?? appointment['Personal'] as String? 
            ?? 'Especialista';

        final date = appointment['fecha'] ?? '';
        final time = (appointment['horaInicio'] ?? '').toString().length >= 5
            ? (appointment['horaInicio'] as String).substring(0, 5)
            : appointment['horaInicio'] ?? '';

        EmailService.sendCancellationEmail(
          toEmail: clientEmail.trim(),
          clientName: clientName,
          serviceName: serviceName,
          staffName: barberName,
          appointmentDate: date,
          appointmentTime: time,
        ).catchError((e) {
          debugPrint('Error sending cancellation email: $e');
          return false;
        });
      }
    } catch (e) {
      debugPrint('Error cancelling appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar la cita: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
