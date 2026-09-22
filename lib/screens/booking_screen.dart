import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';
import '../services/email_service.dart';
import '../services/whatsapp_service.dart';
import 'appointments_history_screen.dart';
// removed unused import

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic>? initialService;

  const BookingScreen({super.key, this.initialService});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // ── Selections ────────────────────────────────────────────────────────────
  String? _selectedBranch;
  List<Map<String, dynamic>> _selectedServices = [];
  Map<String, dynamic>? _selectedBarber;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<String> _branches = [];
  Map<String, String> _branchIds = {};
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _barbers = [];
  List<String> _timeSlots = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFetchingSlots = false;
  bool _verPreciosServicios = false;

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// Total duration in minutes of all selected services.
  int get _totalDurationMinutes {
    if (_selectedServices.isEmpty) return 30;
    return _selectedServices.fold(
      0,
      (sum, s) => sum + ((s['tiempo_servicio'] as int?) ?? 30),
    );
  }

  /// Total price of all selected services.
  num get _totalPrice {
    return _selectedServices.fold<num>(
      0,
      (sum, s) => sum + ((s['Price'] as num?) ?? 0),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.initialService != null) {
      _selectedServices = [widget.initialService!];
    }
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);

      final branchResp = await Supabase.instance.client
          .from('Sucursales')
          .select('IDSucursal, NombreSucursal')
          .eq('IDGeneral', 'FRFROIJNU821')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal Canarios')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal florida');

      final serviceResp = await Supabase.instance.client
          .from('Services')
          .select()
          .order('nameService');

      final generalResp = await Supabase.instance.client
          .from('General')
          .select('verPreciosServicios')
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _branchIds = {
            for (var b in branchResp as List)
              b['NombreSucursal'].toString(): b['IDSucursal'].toString()
          };
          _branches = _branchIds.keys.toList();
          _services = List<Map<String, dynamic>>.from(serviceResp);
          _verPreciosServicios = generalResp?['verPreciosServicios'] ?? false;

          if (_branches.contains(session.selectedBranch)) {
            _selectedBranch = session.selectedBranch;
          } else {
            _selectedBranch = _branches.isNotEmpty ? _branches.first : null;
          }

          // Keep initialService if already set, else leave empty
          if (_selectedServices.isEmpty && _services.isNotEmpty) {
            _selectedServices = [_services.first];
          }

          _isLoading = false;
        });

        if (_selectedBranch != null) {
          _fetchBarbers(_selectedBranch!);
        }
      }
    } catch (e) {
      debugPrint('Error loading booking data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchBarbers(String branch) async {
    setState(() => _barbers = []);
    try {
      final response = await Supabase.instance.client
          .from('Personal')
          .select()
          .eq('sucursal', branch);

      List<Map<String, dynamic>> allBarbers = List<Map<String, dynamic>>.from(
        response,
      );

      // Filter: only barbers that offer ALL selected services
      if (_selectedServices.isNotEmpty) {
        final selectedIds = _selectedServices.map((s) => s['id']).toSet();
        allBarbers = allBarbers.where((b) {
          final List? sIds = b['servicios_ids'] as List?;
          if (sIds == null) return false;
          return selectedIds.every((id) => sIds.contains(id));
        }).toList();
      }

      if (mounted) {
        setState(() {
          _barbers = allBarbers;
          // Refresh selected barber reference (fix Map reference equality)
          if (_selectedBarber != null) {
            final match = allBarbers.firstWhere(
              (b) => b['userID'] == _selectedBarber!['userID'],
              orElse: () => <String, dynamic>{},
            );
            if (match.isNotEmpty) {
              _selectedBarber = match;
            } else {
              _selectedBarber = null;
              _timeSlots = [];
              _selectedTimeSlot = null;
            }
          }

          if (_selectedBarber == null && allBarbers.isNotEmpty) {
            final random = Random();
            _selectedBarber = allBarbers[random.nextInt(allBarbers.length)];
            _generateTimeSlots(_selectedBarber!, _selectedDate);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching barbers: $e');
    }
  }

  // ── Time slot generation ──────────────────────────────────────────────────

  /// Converts a "HH:mm:ss" or "HH:mm" string to total minutes since midnight.
  int _toMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  Future<void> _generateTimeSlots(
    Map<String, dynamic> barber,
    DateTime date,
  ) async {
    // ── Step 1: Build raw slots from the barber's weekly schedule ─────────────
    final List<String> rawSlots = [];
    final horariosRaw = barber['horarios'];
    List? horarios;
    if (horariosRaw != null) {
      if (horariosRaw is String) {
        try {
          horarios = jsonDecode(horariosRaw) as List?;
        } catch (e) {
          debugPrint('Error decoding horarios string: $e');
        }
      } else if (horariosRaw is List) {
        horarios = horariosRaw;
      }
    }

    if (horarios != null) {
      final String dayName = _getDayNameInSpanish(date.weekday);
      final dayConfig = horarios.firstWhere(
        (h) => h['dia'].toString().toLowerCase() == dayName.toLowerCase(),
        orElse: () => null,
      );

      if (dayConfig != null && dayConfig['activo'] != false) {
        final String? startStr = dayConfig['entrada'];
        final String? endStr = dayConfig['salida'];
        final String? lunchStartStr = dayConfig['descanso_inicio'];
        final String? lunchEndStr = dayConfig['descanso_fin'];

        if (startStr != null && endStr != null) {
          int startMin = _toMinutes(startStr);
          int endMin = _toMinutes(endStr);
          // Overnight shift: salida 03:00 + entrada 11:00 → treat as next-day 03:00
          if (endMin <= startMin) endMin += 24 * 60;

          if (endMin - startMin >= _totalDurationMinutes) {
            final int lunchStart = lunchStartStr != null
                ? _toMinutes(lunchStartStr)
                : -1;
            final int lunchEnd = lunchEndStr != null
                ? _toMinutes(lunchEndStr)
                : -1;
            final bool hasLunch = lunchStart >= 0 && lunchEnd > lunchStart;

            int current = startMin;
            while (current + _totalDurationMinutes <= endMin) {
              if (hasLunch) {
                final slotEnd = current + _totalDurationMinutes;
                if (current < lunchEnd && slotEnd > lunchStart) {
                  current = lunchEnd;
                  continue;
                }
              }
              final int clockMin = current % (24 * 60);
              final int h = clockMin ~/ 60;
              final int m = clockMin % 60;
              rawSlots.add(
                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
              );
              current += _totalDurationMinutes;
            }
          }
        }
      }
    }

    // Show loading state while we query existing appointments
    if (mounted)
      setState(() {
        _timeSlots = [];
        _isFetchingSlots = true;
      });

    // ── Step 2: Fetch existing bookings for this barber on this date ──────────
    List<Map<String, dynamic>> bookedAppts = [];
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final resp = await Supabase.instance.client
          .from('Citas')
          .select('horaInicio, horaFin')
          .eq('barberoID', barber['userID'])
          .eq('fecha', dateStr)
          .neq('estatus', 'Cancelada');

      bookedAppts = List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      debugPrint('Error fetching booked slots: $e');
    }

    // ── Step 3: Filter out slots that overlap any existing appointment ────────
    //
    // Overlap rule: two intervals [A, A+d) and [B, B+d) overlap when
    //               A < B_end  AND  A_end > B_start
    //
    final now = DateTime.now();
    final bool isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final int nowMinutes = now.hour * 60 + now.minute;

    final List<String> available = rawSlots.where((slot) {
      final int slotStart = _toMinutes(slot);

      // Si la fecha seleccionada es hoy, no mostrar horarios inferiores al actual
      if (isToday && slotStart < nowMinutes) {
        return false;
      }

      final int slotEnd = slotStart + _totalDurationMinutes;

      for (final appt in bookedAppts) {
        final int bookedStart = _toMinutes(
          appt['horaInicio'] as String? ?? '00:00',
        );
        int bookedEnd = _toMinutes(appt['horaFin'] as String? ?? '00:00');
        // Guard against horaFin == 00:00 (no end stored) — treat as at least 1 slot long
        if (bookedEnd <= bookedStart) bookedEnd = bookedStart + 30;

        if (slotStart < bookedEnd && slotEnd > bookedStart) {
          return false; // Overlaps → remove this slot
        }
      }
      return true;
    }).toList();

    if (mounted) {
      setState(() {
        _isFetchingSlots = false;
        _timeSlots = available;
        if (_selectedTimeSlot != null &&
            !available.contains(_selectedTimeSlot)) {
          _selectedTimeSlot = null;
        }
      });
    }
  }

  String _getDayNameInSpanish(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunes';
      case DateTime.tuesday:
        return 'Martes';
      case DateTime.wednesday:
        return 'Miércoles';
      case DateTime.thursday:
        return 'Jueves';
      case DateTime.friday:
        return 'Viernes';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return '';
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveBooking() async {
    if (_selectedBranch == null ||
        _selectedServices.isEmpty ||
        _selectedBarber == null ||
        _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todas las selecciones.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);

      Map<String, dynamic>? clientResp;
      if (session.userId != null) {
        clientResp = await Supabase.instance.client
            .from('clientes')
            .select('IDCliente, nombre, telefono, correo')
            .eq('IDCliente', session.userId!)
            .maybeSingle();
      }

      if (clientResp == null && session.userEmail != null) {
        clientResp = await Supabase.instance.client
            .from('clientes')
            .select('IDCliente, nombre, telefono, correo')
            .or(
              'telefono.eq.${session.userEmail},correo.eq.${session.userEmail}',
            )
            .maybeSingle();
      }

      if (clientResp == null)
        throw Exception('No se encontró el registro de cliente.');

      // Calculate end time from start + total duration
      final startMinutes = _toMinutes(_selectedTimeSlot!);
      final endMinutes = startMinutes + _totalDurationMinutes;
      final endH = (endMinutes ~/ 60) % 24;
      final endM = endMinutes % 60;
      final endTimeStr =
          '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}:00';

      // Primary service ID (for FK). If multiple, use first one.
      final primaryServiceId = _selectedServices.first['id'];
      // Human-readable combined name stored as a note
      final serviceNames = _selectedServices
          .map((s) => s['nameService'])
          .join(', ');

      final branchId = _selectedBranch != null ? _branchIds[_selectedBranch] : null;
      await Supabase.instance.client.from('Citas').insert({
        'clienteID': clientResp['IDCliente'],
        'barberoID': _selectedBarber!['userID'],
        'servicioID': primaryServiceId,
        'fecha': _selectedDate.toIso8601String().split('T')[0],
        'horaInicio': '$_selectedTimeSlot:00',
        'horaFin': endTimeStr,
        'sucursal': _selectedBranch,
        if (branchId != null) 'sucursal_id': branchId,
        'precioFinal': _totalPrice,
        'estatus': 'Activa',
      });

      // Prepare date and price formatting for WhatsApp
      final dateStr =
          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
      final priceStr = '\$${_totalPrice.toStringAsFixed(0)}';

      // Enviar notificaciones de manera segura en segundo plano para no bloquear al usuario ni fallar si falla un servicio externo
      final currentClientResp = clientResp;
      () async {
        try {
          final email = currentClientResp['correo'] as String?;
          if (email != null && email.trim().isNotEmpty) {
            try {
              // 1. Correo de confirmación para el cliente
              await EmailService.sendBookingEmail(
                toEmail: email.trim(),
                clientName: currentClientResp['nombre'] ?? 'Cliente',
                serviceName: _selectedServices.length > 1
                    ? serviceNames
                    : _selectedServices.first['nameService'],
                staffName: _selectedBarber!['nombre'] ?? 'Personal',
                appointmentDate: dateStr,
                appointmentTime: _selectedTimeSlot ?? '',
                price: priceStr,
              );
            } catch (e) {
              debugPrint(
                'Error sending booking confirmation email to client: $e',
              );
            }

            try {
              // 2. Correo de detalles para el miembro del personal asignado
              final staffEmail = _selectedBarber!['correo'] as String?;
              if (staffEmail != null && staffEmail.trim().isNotEmpty) {
                await EmailService.sendStaffBookingEmail(
                  staffEmail: staffEmail.trim(),
                  staffName: _selectedBarber!['nombre'] ?? 'Personal',
                  clientName: currentClientResp['nombre'] ?? 'Cliente',
                  clientPhone: currentClientResp['telefono'] ?? 'Sin teléfono',
                  clientEmail: email.trim(),
                  serviceName: _selectedServices.length > 1
                      ? serviceNames
                      : _selectedServices.first['nameService'],
                  appointmentDate: dateStr,
                  appointmentTime: _selectedTimeSlot ?? '',
                  price: priceStr,
                );
              }
            } catch (e) {
              debugPrint('Error sending booking details email to staff: $e');
            }
          }

          // 3. Correo de notificación general al administrador master
          try {
            await EmailService.sendGeneralBookingNotificationEmail(
              clientName: currentClientResp['nombre'] ?? 'Cliente',
              clientPhone: currentClientResp['telefono'] ?? 'Sin teléfono',
              clientEmail: (email != null && email.trim().isNotEmpty)
                  ? email.trim()
                  : 'Sin correo registrado',
              serviceName: _selectedServices.length > 1
                  ? serviceNames
                  : _selectedServices.first['nameService'],
              staffName: _selectedBarber!['nombre'] ?? 'Personal',
              appointmentDate: dateStr,
              appointmentTime: _selectedTimeSlot ?? '',
              price: priceStr,
            );
          } catch (e) {
            debugPrint(
              'Error sending general master booking notification email: $e',
            );
          }

          // 4. Enviamos la alerta de WhatsApp al negocio/administración de forma silenciosa
          try {
            await _sendWhatsAppNotification(
              clientName: currentClientResp['nombre'] ?? 'Cliente',
              serviceName: _selectedServices.length > 1
                  ? serviceNames
                  : _selectedServices.first['nameService'],
              staffName: _selectedBarber!['nombre'] ?? 'Personal',
              appointmentDate: dateStr,
              appointmentTime: _selectedTimeSlot ?? '',
              price: priceStr,
              clientPhone: currentClientResp['telefono'] ?? '',
              isSilent:
                  true, // No interrumpir al cliente si hay errores con el envío
            );
          } catch (e) {
            debugPrint('Error sending WhatsApp notification to admin: $e');
          }

          // 5. Enviamos la alerta de WhatsApp al miembro del personal de forma silenciosa
          final staffPhone = _selectedBarber!['telefono'] as String?;
          if (staffPhone != null && staffPhone.trim().isNotEmpty) {
            try {
              await _sendWhatsAppNotification(
                clientName: currentClientResp['nombre'] ?? 'Cliente',
                serviceName: _selectedServices.length > 1
                    ? serviceNames
                    : _selectedServices.first['nameService'],
                staffName: _selectedBarber!['nombre'] ?? 'Personal',
                appointmentDate: dateStr,
                appointmentTime: _selectedTimeSlot ?? '',
                price: priceStr,
                clientPhone: '0',
                sendToOverride: staffPhone,
                hidePhoneForStaff: true,
                isSilent: true,
              );
            } catch (e) {
              debugPrint('Error sending WhatsApp notification to staff: $e');
            }
          }

          // 6. Enviamos la alerta de WhatsApp al cliente de forma silenciosa
          final clientPhone = currentClientResp['telefono'] as String?;
          if (clientPhone != null && clientPhone.trim().isNotEmpty) {
            try {
              await _sendWhatsAppNotification(
                clientName: currentClientResp['nombre'] ?? 'Cliente',
                serviceName: _selectedServices.length > 1
                    ? serviceNames
                    : _selectedServices.first['nameService'],
                staffName: _selectedBarber!['nombre'] ?? 'Personal',
                appointmentDate: dateStr,
                appointmentTime: _selectedTimeSlot ?? '',
                price: priceStr,
                clientPhone: clientPhone,
                sendToOverride: clientPhone,
                isSilent: true,
              );
            } catch (e) {
              debugPrint('Error sending WhatsApp notification to client: $e');
            }
          }
        } catch (e) {
          debugPrint('General error in background notifications: $e');
        }
      }();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cita agendada con éxito!')),
        );
        // Navigate to Mis Citas, clearing the booking screen from the stack.
        // Back from Mis Citas goes to the Home (the first route).
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentsHistoryScreen()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al agendar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _cleanAndFormatPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '5215613964584'; // fallback
    if (cleaned.length == 10) {
      return '521$cleaned';
    }
    if (cleaned.startsWith('52') && cleaned.length == 12) {
      return '521${cleaned.substring(2)}';
    }
    return cleaned;
  }

  Future<bool> _sendWhatsAppNotification({
    required String clientName,
    required String serviceName,
    required String staffName,
    required String appointmentDate,
    required String appointmentTime,
    required String price,
    required String clientPhone,
    String? sendToOverride,
    bool hidePhoneForStaff = false,
    bool isSilent = false,
  }) async {
    try {
      // Saneamos todos los campos para evitar que contengan cadenas vacías
      // La API de WhatsApp rechaza de inmediato el envío si algún parámetro de body está vacío.
      final clientNameClean = clientName.trim().isEmpty
          ? 'Cliente'
          : clientName.trim();
      final serviceNameClean = serviceName.trim().isEmpty
          ? 'Servicios'
          : serviceName.trim();
      final staffNameClean = staffName.trim().isEmpty
          ? 'Personal'
          : staffName.trim();
      final dateClean = appointmentDate.trim().isEmpty
          ? 'Hoy'
          : appointmentDate.trim();
      final timeClean = appointmentTime.trim().isEmpty
          ? 'Pendiente'
          : appointmentTime.trim();
      final priceClean = price.trim().isEmpty ? '\$0' : price.trim();
      final clientPhoneClean = hidePhoneForStaff
          ? '0'
          : _cleanAndFormatPhone(clientPhone);

      // Destinatario: override (número de WhatsApp del barbero) o número fijo del negocio
      final targetPhone =
          sendToOverride != null && sendToOverride.trim().isNotEmpty
          ? _cleanAndFormatPhone(sendToOverride)
          : "525519553555";

      final secrets = await WhatsAppService.getWhatsAppSecrets();
      final bearerToken = secrets['whatsapp_token'];
      final phoneId = secrets['whatsapp_phone_number_id'];

      final uri = Uri.parse(
        'https://graph.facebook.com/v17.0/$phoneId/messages',
      );

      final body = {
        "messaging_product": "whatsapp",
        "to": targetPhone,
        "type": "template",
        "template": {
          "name": "alerta_agendacita_para_negocio",
          "language": {"code": "es_MX"},
          "components": [
            {
              "type": "body",
              "parameters": [
                {"type": "text", "text": clientNameClean}, // {{1}} -> Nombre
                {"type": "text", "text": serviceNameClean}, // {{2}} -> Servicio
                {"type": "text", "text": staffNameClean}, // {{3}} -> Personal
                {"type": "text", "text": dateClean}, // {{4}} -> Dia
                {"type": "text", "text": timeClean}, // {{5}} -> Hora
                {"type": "text", "text": priceClean}, // {{6}} -> Precio
                {"type": "text", "text": clientPhoneClean}, // {{7}} -> WhatsApp
              ],
            },
          ],
        },
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
        body: jsonEncode(body),
      );
      final responseBody = response.body;
      debugPrint('WhatsApp Notification Status: ${response.statusCode}');
      debugPrint('WhatsApp Notification Response: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        if (!isSilent && mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Error de WhatsApp API'),
              content: SingleChildScrollView(
                child: Text(
                  'Código: ${response.statusCode}\n\nRespuesta de Facebook:\n$responseBody',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('WhatsApp Notification Error: $e');
      if (!isSilent && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error de Conexión'),
            content: Text('No se pudo contactar al servidor:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
      return false;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Agendar Cita',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Sucursal ────────────────────────────────────────────
                  _buildLabel('Sucursal'),
                  _buildDropdown<String>(
                    value: _selectedBranch,
                    items: _branches
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBranch = val;
                        _selectedBarber = null;
                        _selectedTimeSlot = null;
                        _timeSlots = [];
                      });
                      if (val != null) _fetchBarbers(val);
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Servicios (multi-select) ─────────────────────────────
                  _buildLabel('Servicios'),
                  _buildServicesSelector(),
                  if (_selectedServices.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildServiceSummary(),
                  ],
                  const SizedBox(height: 20),

                  // ── Barbero ─────────────────────────────────────────────
                  _buildLabel('Personal / Barbero'),
                  _buildDropdown<Map<String, dynamic>>(
                    value: _selectedBarber,
                    items: _barbers
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(b['nombre'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBarber = val;
                        _selectedTimeSlot = null;
                        _timeSlots = [];
                      });
                      if (val != null) _generateTimeSlots(val, _selectedDate);
                    },
                    hint: _barbers.isEmpty
                        ? 'No hay personal disponible'
                        : 'Selecciona un profesional',
                  ),
                  const SizedBox(height: 20),

                  // ── Fecha ────────────────────────────────────────────────
                  _buildLabel('Fecha'),
                  _buildDatePicker(),
                  const SizedBox(height: 20),

                  // ── Horarios ─────────────────────────────────────────────
                  _buildLabel('Horario Disponible'),
                  _buildTimeSlots(),
                  const SizedBox(height: 40),

                  // ── Confirmar ────────────────────────────────────────────
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _selectedServices.isEmpty
                                ? 'Confirmar Reserva'
                                : (_verPreciosServicios
                                      ? 'Confirmar • \$${_totalPrice.toStringAsFixed(0)}'
                                      : 'Confirmar Reserva'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Widget builders ───────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    T? value,
    required List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? onChanged,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint ?? '', style: const TextStyle(color: Colors.grey)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Chip-based multi-service selector.
  Widget _buildServicesSelector() {
    // Compute available services: if a barber is selected, only show theirs
    final available = _services.where((s) {
      if (_selectedBarber != null) {
        final List? sIds = _selectedBarber!['servicios_ids'] as List?;
        return sIds != null && sIds.contains(s['id']);
      }
      return true;
    }).toList();

    if (available.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          'No hay servicios disponibles',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: available.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final s = available[idx];
          final isSelected = _selectedServices.any(
            (sel) => sel['id'] == s['id'],
          );
          final minutes = (s['tiempo_servicio'] as int?) ?? 30;
          final price = (s['Price'] as num?) ?? 0;

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedServices.removeWhere((sel) => sel['id'] == s['id']);
                } else {
                  _selectedServices.add(s);
                }
                _selectedTimeSlot = null;
                _timeSlots = [];
              });
              if (_selectedBranch != null) {
                _fetchBarbers(_selectedBranch!).then((_) {
                  if (_selectedBarber != null) {
                    _generateTimeSlots(_selectedBarber!, _selectedDate);
                  }
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 142,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          s['nameService'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    _verPreciosServicios
                        ? '${_formatDuration(minutes)}  ·  \$$price'
                        : _formatDuration(minutes),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Summary bar showing totals.
  Widget _buildServiceSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'Total: ${_formatDuration(_totalDurationMinutes)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_verPreciosServicios)
            Text(
              '\$${_totalPrice.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    final days = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final months = [
      '',
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
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 60)),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: Colors.black),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
            _selectedTimeSlot = null;
          });
          if (_selectedBarber != null) {
            _generateTimeSlots(_selectedBarber!, date);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Colors.black54),
            const SizedBox(width: 12),
            Text(
              '${days[_selectedDate.weekday]} ${_selectedDate.day} de ${months[_selectedDate.month]} ${_selectedDate.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlots() {
    if (_selectedBarber == null) {
      return _buildHint(
        Icons.person_outline,
        'Selecciona un barbero para ver horarios',
      );
    }
    if (_selectedServices.isEmpty) {
      return _buildHint(Icons.spa_outlined, 'Selecciona al menos un servicio');
    }
    if (_isFetchingSlots) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
        ),
      );
    }
    if (_timeSlots.isEmpty) {
      return _buildHint(
        Icons.event_busy,
        'Sin horarios disponibles para este día.',
        isError: true,
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _timeSlots.map((time) {
        final isSelected = _selectedTimeSlot == time;
        return GestureDetector(
          onTap: () => setState(() => _selectedTimeSlot = time),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey.shade300,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              time,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHint(IconData icon, String text, {bool isError = false}) {
    return Row(
      children: [
        Icon(icon, color: isError ? Colors.redAccent : Colors.grey, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isError ? Colors.redAccent : Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
