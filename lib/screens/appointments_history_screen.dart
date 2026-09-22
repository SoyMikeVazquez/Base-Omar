import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';

class AppointmentsHistoryScreen extends StatefulWidget {
  const AppointmentsHistoryScreen({super.key});

  @override
  State<AppointmentsHistoryScreen> createState() => _AppointmentsHistoryScreenState();
}

class _AppointmentsHistoryScreenState extends State<AppointmentsHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  bool _showPrice = false; // controlled by General config

  @override
  void initState() {
    super.initState();
    _fetchConfig();
    _fetchAppointments();
  }

  Future<void> _fetchConfig() async {
    try {
      final resp = await Supabase.instance.client
          .from('General')
          .select('verPreciosServicios')
          .maybeSingle();
      if (mounted && resp != null) {
        setState(() {
          _showPrice = resp['verPreciosServicios'] == true;
        });
      }
    } catch (e) {
      debugPrint('Error fetching General config: $e');
    }
  }

  Future<void> _fetchAppointments() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      if (session.userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. Fetch raw appointments
      final response = await Supabase.instance.client
          .from('Citas')
          .select()
          .eq('clienteID', session.userId!)
          .order('fecha', ascending: false)
          .order('horaInicio', ascending: false);

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

      // 2. Fetch client info
      final clientInfo = await Supabase.instance.client
          .from('clientes')
          .select('nombre, telefono, correo')
          .eq('IDCliente', session.userId!)
          .maybeSingle();

      // 3. Extract unique barber and service IDs
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

      // 4. Fetch barber details
      List<Map<String, dynamic>> barbers = [];
      if (barberIds.isNotEmpty) {
        final barbResp = await Supabase.instance.client
            .from('Personal')
            .select('userID, nombre')
            .inFilter('userID', barberIds);
        barbers = List<Map<String, dynamic>>.from(barbResp);
      }

      // 5. Fetch service details
      List<Map<String, dynamic>> services = [];
      if (serviceIds.isNotEmpty) {
        final servResp = await Supabase.instance.client
            .from('Services')
            .select('id, nameService')
            .inFilter('id', serviceIds);
        services = List<Map<String, dynamic>>.from(servResp);
      }

      // 6. Join in memory
      final joined = appts.map((appt) {
        final bId = appt['barberoID']?.toString();
        final sId = appt['servicioID']?.toString();

        final barber = barbers.firstWhere(
          (b) => b['userID']?.toString() == bId,
          orElse: () => <String, dynamic>{'nombre': 'Sin asignar'},
        );

        final service = services.firstWhere(
          (s) => s['id']?.toString() == sId,
          orElse: () => <String, dynamic>{'nameService': 'Servicio'},
        );

        return {
          ...appt,
          'clientes': clientInfo,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Mis Citas',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _appointments.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchAppointments,
                  color: Colors.black,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = _appointments[index];
                      return _buildAppointmentCard(appointment);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'No tienes citas agendadas',
            style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tus citas aparecerán aquí.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final barberName = appointment['Personal']?['nombre'] ?? 'Sin asignar';
    // Multi-service: use notas if available, otherwise fall back to single service name
    final notas = appointment['notas'] as String?;
    final serviceName = (notas != null && notas.isNotEmpty)
        ? notas
        : (appointment['Services']?['nameService'] ?? 'Servicio');
    // Split into individual service chips for display
    final serviceList = serviceName.split(',').map((s) => s.trim()).toList();
    final date = appointment['fecha'] ?? '';
    final time = (appointment['horaInicio'] ?? '').toString().length >= 5
        ? (appointment['horaInicio'] as String).substring(0, 5)
        : appointment['horaInicio'] ?? '';
    final status = appointment['estatus'] ?? 'Pendiente';
    final price = appointment['precioFinal'] ?? 0;

    return GestureDetector(
      onTap: () => _showAppointmentDetails(context, appointment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: barbero + status ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Con $barberName',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 10),
              // ── Services chips ────────────────────────────────────────────
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: serviceList.map<Widget>((svc) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    svc,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                )).toList(),
              ),
              const Divider(height: 24),
              // ── Date / time / price row ───────────────────────────────────
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Text(date, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Text(time, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const Spacer(),
                  Text(
                    '\$$price',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppointmentDetails(BuildContext context, Map<String, dynamic> appointment) {
    final clientData = appointment['clientes'] as Map<String, dynamic>?;
    final clientName = clientData?['nombre'] as String? ?? 'Sin nombre';
    final clientPhone = clientData?['telefono'] as String?;
    final clientEmail = clientData?['correo'] as String?;

    final barberName = appointment['Personal'] is String
        ? appointment['Personal'] as String
        : appointment['Personal']?['nombre'] ?? 'Sin asignar';
    final serviceName = appointment['Servicios'] as String?
        ?? appointment['Services']?['nameService'] as String?
        ?? 'Servicio';
    final branch = appointment['Sucursal'] as String?
        ?? appointment['sucursal'] as String?
        ?? 'General';
    final price = appointment['MontoACobrar'] ?? appointment['precioFinal'] ?? 0;

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
              if (clientPhone != null && clientPhone.isNotEmpty)
                _buildDetailItem(Icons.phone_outlined, 'Teléfono del Cliente', clientPhone),
              if (clientEmail != null && clientEmail.isNotEmpty)
                _buildDetailItem(Icons.mail_outline, 'Correo del Cliente', clientEmail),
              _buildDetailItem(Icons.content_cut, 'Servicio(s)', serviceName),
              _buildDetailItem(Icons.storefront_outlined, 'Sucursal', branch),
              _buildDetailItem(Icons.face, 'Personal Asignado', barberName),
              _buildDetailItem(Icons.calendar_today_outlined, 'Fecha', date),
              _buildDetailItem(Icons.access_time, 'Hora', time),
              if (_showPrice)
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
