import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/session_provider.dart';
import '../services/email_service.dart';

class GeneralAgendaScreen extends StatefulWidget {
  const GeneralAgendaScreen({super.key});

  @override
  State<GeneralAgendaScreen> createState() => _GeneralAgendaScreenState();
}

class _GeneralAgendaScreenState extends State<GeneralAgendaScreen> {
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _appointments = [];

  final ScrollController _dateScrollController = ScrollController();
  final List<DateTime> _dates = [];

  @override
  void initState() {
    super.initState();
    _generateDatesAround(_selectedDate);
    _initAgendaData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(animate: false);
    });
  }

  void _generateDatesAround(DateTime baseDate) {
    _dates.clear();
    for (int i = -100; i <= 100; i++) {
      _dates.add(baseDate.add(Duration(days: i)));
    }
  }

  void _scrollToSelectedDate({bool animate = true}) {
    if (!_dateScrollController.hasClients) return;

    final index = _dates.indexWhere((date) =>
        date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day);

    if (index != -1) {
      const itemWidth = 72.0; // 60 width + 12 margin
      final screenWidth = MediaQuery.of(context).size.width;
      final offset = (index * itemWidth) - (screenWidth / 2) + 36.0;

      final maxScroll = _dateScrollController.position.maxScrollExtent;
      final targetScroll = offset.clamp(0.0, maxScroll);

      if (animate) {
        _dateScrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _dateScrollController.jumpTo(targetScroll);
      }
    }
  }

  Future<void> _initAgendaData() async {
    try {
      await _fetchAppointmentsForSelectedDate();
    } catch (e) {
      debugPrint('Error initAgendaData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAppointmentsForSelectedDate() async {
    setState(() => _isLoading = true);
    
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (session.userId == null) {
      _loadMockAppointments();
      return;
    }
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
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
      debugPrint('Error fetching general appointments: $e');
      if (mounted) {
        _loadMockAppointments();
      }
    }
  }

  void _loadMockAppointments() {
    final dayOfWeek = _selectedDate.weekday;
    final dayNum = _selectedDate.day;
    
    if (dayOfWeek == DateTime.sunday) {
      setState(() {
        _appointments = [];
        _isLoading = false;
      });
      return;
    }
    
    final List<Map<String, dynamic>> mockList = [];
    
    if (dayNum % 2 == 0) {
      mockList.add({
        'horaInicio': '09:00',
        'precioCobrado': 450,
        'estatus': 'Confirmada',
        'clientes': {'nombre': 'Carlos Mendoza', 'telefono': '55 4321 8765'},
        'Services': {'nameService': 'Corte Clásico'},
        'Personal': {'nombre': 'Mike Barber'},
      });
      mockList.add({
        'horaInicio': '14:30',
        'precioCobrado': 300,
        'estatus': 'Completada',
        'clientes': {'nombre': 'Lucía Gómez', 'telefono': '55 9876 5432'},
        'Services': {'nameService': 'Perfilado de Cejas'},
        'Personal': {'nombre': 'Ana Estilista'},
      });
    } else {
      mockList.add({
        'horaInicio': '10:00',
        'precioCobrado': 650,
        'estatus': 'Pendiente',
        'clientes': {'nombre': 'María Sánchez', 'telefono': '55 1234 5678'},
        'Services': {'nameService': 'Corte + Tinte'},
        'Personal': {'nombre': 'Ana Estilista'},
      });
      mockList.add({
        'horaInicio': '11:30',
        'precioCobrado': 280,
        'estatus': 'Completada',
        'clientes': {'nombre': 'Sofía Ramírez', 'telefono': '55 8765 4321'},
        'Services': {'nameService': 'Manicure Gel'},
        'Personal': {'nombre': 'Mike Barber'},
      });
      mockList.add({
        'horaInicio': '13:00',
        'precioCobrado': 900,
        'estatus': 'Pendiente',
        'clientes': {'nombre': 'Valentina Cruz', 'telefono': ''},
        'Services': {'nameService': 'Peinado de Novia'},
        'Personal': {'nombre': 'Ana Estilista'},
      });
    }
    
    setState(() {
      _appointments = mockList;
      _isLoading = false;
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _fetchAppointmentsForSelectedDate();
    _scrollToSelectedDate();
  }

  Future<void> _selectDateFromCalendar() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _generateDatesAround(picked);
      _fetchAppointmentsForSelectedDate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedDate(animate: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Agenda General', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: Colors.black),
            onPressed: _selectDateFromCalendar,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHorizontalCalendar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _appointments.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchAppointmentsForSelectedDate,
                        color: Colors.black,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            return _buildAppointmentCard(_appointments[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar() {
    final monthYearStr = DateFormat('MMMM yyyy', 'es').format(_selectedDate);
    final formattedMonthYear = monthYearStr[0].toUpperCase() + monthYearStr.substring(1);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 4),
            child: Text(
              formattedMonthYear,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              controller: _dateScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                final isSelected = date.year == _selectedDate.year &&
                                   date.month == _selectedDate.month &&
                                   date.day == _selectedDate.day;
                
                final dayName = DateFormat('E', 'es').format(date).toUpperCase();
                final dayNum = date.day.toString();

                return GestureDetector(
                  onTap: () => _onDateSelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 12),
                    width: 60,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayNum,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text(
            'Sin Citas',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          const Text(
            'No hay citas agendadas para este día.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final clientData = appointment['clientes'] as Map<String, dynamic>? ?? {};
    final serviceData = appointment['Services'] as Map<String, dynamic>? ?? {};
    
    final clientName = clientData['nombre'] ?? appointment['nombreClienteTemporal'] ?? appointment['NombreCliente'] ?? 'Cliente Desconocido';
    final clientPhone = clientData['telefono'] ?? appointment['telefonoClienteTemporal'] ?? appointment['NumeroTelefonoC'] ?? '';
    final serviceName = serviceData['nameService'] ?? appointment['nombreServicioPersonalizado'] ?? appointment['Servicios'] ?? 'Servicio';
    final timeStart = appointment['horaInicio'] ?? '--:--';
    final rawPrice = appointment['precioCobrado'] ?? appointment['precioFinal'] ?? appointment['MontoACobrar'] ?? 0;
    
    // Evitar duplicación de signos de pesos
    final priceStr = rawPrice.toString().startsWith('\$') ? rawPrice.toString() : '\$$rawPrice';
    
    final isCompleted = appointment['estatus']?.toString().toLowerCase() == 'completada' || appointment['completada'] == true;

    final barberName = appointment['Personal'] is String 
        ? appointment['Personal'] as String 
        : appointment['Personal']?['nombre'] ?? 'Sin asignar';

    return GestureDetector(
      onTap: () => _showAppointmentDetails(context, appointment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeStart,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green.shade700 : Colors.black,
                    ),
                  ),
                ),
                if (isCompleted)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text('Completada', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black87,
                  child: Text(
                    clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        serviceName,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.face, size: 14, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            'Asignado: $barberName',
                            style: const TextStyle(color: Colors.black45, fontSize: 12),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
            if (clientPhone.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(clientPhone, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  void _showAppointmentDetails(BuildContext context, Map<String, dynamic> appointment) {
    final barberName = appointment['Personal'] is String ? appointment['Personal'] as String : appointment['Personal']?['nombre'] ?? 'Sin asignar';
    final serviceName = appointment['Servicios'] as String? ?? appointment['notas'] as String? ?? appointment['Services']?['nameService'] ?? 'Servicio';
    final clientName = appointment['NombreCliente'] as String? ?? appointment['clientes']?['nombre'] ?? 'Cliente';
    final clientEmail = appointment['CorreoCliente'] as String? ?? appointment['clientes']?['correo'] ?? 'Sin correo';
    final clientPhone = appointment['NumeroTelefonoC'] as String? ?? appointment['clientes']?['telefono'] ?? 'Sin teléfono';
    final branch = appointment['Sucursal'] as String? ?? appointment['sucursal'] as String? ?? 'General';
    final price = appointment['MontoACobrar'] ?? appointment['precioFinal'] ?? appointment['precioCobrado'] ?? 0;
    
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
              _buildDetailItem(Icons.phone_outlined, 'Teléfono del Cliente', clientPhone),
              _buildDetailItem(Icons.mail_outline, 'Correo del Cliente', clientEmail),
              _buildDetailItem(Icons.content_cut, 'Servicio(s)', serviceName),
              _buildDetailItem(Icons.storefront_outlined, 'Sucursal', branch),
              _buildDetailItem(Icons.face, 'Personal Asignado', barberName),
              _buildDetailItem(Icons.calendar_today_outlined, 'Fecha', date),
              _buildDetailItem(Icons.access_time, 'Hora', time),
              _buildDetailItem(Icons.attach_money, 'Monto a Cobrar', '\$$price'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estatus',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  _buildStatusBadge(status),
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

      await _fetchAppointmentsForSelectedDate();
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

      await _fetchAppointmentsForSelectedDate();

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
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmada':
      case 'activa':
        color = Colors.green;
        break;
      case 'completada':
        color = Colors.blue;
        break;
      case 'cancelada':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
