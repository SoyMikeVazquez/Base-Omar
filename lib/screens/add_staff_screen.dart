import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_text_field.dart';

class AddStaffScreen extends StatefulWidget {
  final Map<String, dynamic>? editStaff;
  const AddStaffScreen({super.key, this.editStaff});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _whatsappController = TextEditingController();
  
  // Certificate Fields
  final _certNombreController = TextEditingController();
  final _certCedulaController = TextEditingController();
  final _certAvalacionController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedBranch;
  List<String> _branches = [];
  bool _isLoadingBranches = true;

  // Roles y Tipo de Personal
  String? _selectedTipoPersonal = 'Barbero';

  bool get _isPersonal => _selectedTipoPersonal == 'Barbero' || _selectedTipoPersonal == 'Estilista';
  bool get _isAdmin => _selectedTipoPersonal == 'Administrador';
  bool get _isRecepcion => _selectedTipoPersonal == 'Recepcionista';
  bool get _isGestor => _selectedTipoPersonal == 'Gestor';


  // Profile Picture
  XFile? _profileImageFile;
  Uint8List? _profileImageBytes;
  String? _currentImageUrl;
  bool _mostrarFoto = true;

  // Services
  List<Map<String, dynamic>> _services = [];
  List<String> _selectedServiceIds = [];
  bool _isLoadingServices = true;

  // Certificate Toggle
  bool _tieneCertificado = false;

  // Schedule List (Google Maps style)
  List<Map<String, dynamic>> _dailySchedules = [
    {'day': 'Lunes', 'isActive': true, 'entrada': null, 'salida': null, 'descanso_inicio': null, 'descanso_fin': null},
    {'day': 'Martes', 'isActive': true, 'entrada': null, 'salida': null, 'descanso_inicio': null, 'descanso_fin': null},
    {'day': 'Miércoles', 'isActive': true, 'entrada': null, 'salida': null, 'descanso_inicio': null, 'descanso_fin': null},
    {'day': 'Jueves', 'isActive': true, 'entrada': null, 'salida': null, 'descanso_inicio': null, 'descanso_fin': null},
    {'day': 'Viernes', 'isActive': true, 'entrada': null, 'salida': null, 'descanso_inicio': null, 'descanso_fin': null},
    {'day': 'Sábado', 'isActive': true, 'entrada': null, 'salida': null, 'descanso_inicio': null, 'descanso_fin': null},
    {'day': 'Domingo', 'isActive': false, 'entrada': null, 'salida': null, 'descanso_inicio': null, 'descanso_fin': null},
  ];

  @override
  void initState() {
    super.initState();
    _fetchBranches().then((_) {
      if (widget.editStaff != null) {
        _loadEditData();
      }
    });
    _fetchServices();
  }

  void _loadEditData() {
    final s = widget.editStaff!;
    _nameController.text = s['nombre'] ?? '';
    _emailController.text = s['correo'] ?? '';
    _whatsappController.text = s['telefono'] ?? '';
    _selectedBranch = s['sucursal'];
    _currentImageUrl = s['foto_perfil'];
    _mostrarFoto = s['mostrar_foto'] ?? true;
    _tieneCertificado = s['tiene_certificado'] ?? false;
    _certNombreController.text = s['certificado_nombre'] ?? '';
    _certCedulaController.text = s['certificado_cedula'] ?? '';
    _certAvalacionController.text = s['certificado_avalacion'] ?? '';
    _selectedTipoPersonal = s['TipoPersonal'] ?? 'Barbero';
    
    if (s['servicios_ids'] != null) {
      _selectedServiceIds = List<String>.from(s['servicios_ids']);
    }

    if (s['horarios'] != null) {
      final List h = s['horarios'] is String ? jsonDecode(s['horarios']) : List.from(s['horarios']);
      for (int i = 0; i < h.length; i++) {
        final dayData = h[i];
        final index = _dailySchedules.indexWhere((d) => d['day'] == dayData['dia']);
        if (index != -1) {
          _dailySchedules[index]['isActive'] = dayData['activo'] ?? false;
          _dailySchedules[index]['entrada'] = _parseTime(dayData['entrada']);
          _dailySchedules[index]['salida'] = _parseTime(dayData['salida']);
          _dailySchedules[index]['descanso_inicio'] = _parseTime(dayData['descanso_inicio']);
          _dailySchedules[index]['descanso_fin'] = _parseTime(dayData['descanso_fin']);
        }
      }
    }

    // Load roles from 'users' table if needed, or assume from staff info if possible
    _fetchUserRoles(s['userID']);
  }

  Future<void> _fetchUserRoles(String? userId) async {
    if (userId == null) return;
    try {
      final res = await Supabase.instance.client.from('users').select().eq('IDUser', userId).single();
      if (mounted) {
        setState(() {
          final isP = res['isPersonal'] ?? false;
          final isA = res['isAdmin'] ?? false;
          final isR = res['isRecepcion'] ?? false;
          final isG = res['isGestor'] ?? false;

          if (isA) {
            _selectedTipoPersonal = 'Administrador';
          } else if (isR) {
            _selectedTipoPersonal = 'Recepcionista';
          } else if (isG) {
            _selectedTipoPersonal = 'Gestor';
          } else if (isP) {
            if (_selectedTipoPersonal != 'Barbero' && _selectedTipoPersonal != 'Estilista') {
              _selectedTipoPersonal = 'Barbero';
            }
          }
        });
      }
    } catch (_) {}
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr == '00:00:00' || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await Supabase.instance.client
          .from('Sucursales')
          .select('NombreSucursal')
          .eq('IDGeneral', 'FRFROIJNU821')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal Canarios')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal florida')
          .order('NombreSucursal', ascending: true);
      
      final branchNames = List<String>.from(
        (response as List).map((b) => b['NombreSucursal'] as String)
      );

      if (mounted) {
        setState(() {
          _branches = branchNames;
          _isLoadingBranches = false;
          if (_selectedBranch == null && _branches.contains("Omar's Barber - Sucursal Montealto")) {
            _selectedBranch = "Omar's Barber - Sucursal Montealto";
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBranches = false);
    }
  }

  Future<void> _fetchServices() async {
    try {
      final response = await Supabase.instance.client
          .from('Services')
          .select('id, nameService')
          .order('nameService', ascending: true);
      
      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(response);
          _isLoadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _profileImageFile = file;
        _profileImageBytes = bytes;
      });
    }
  }

  Future<void> _pickTimeForDay(int dayIndex, String field) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dailySchedules[dayIndex][field] ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _dailySchedules[dayIndex][field] = picked;
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    final hour = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String? _toDbTime(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_profileImageBytes == null) return _currentImageUrl;
    
    try {
      final ext = _profileImageFile?.name.split('.').last ?? 'jpg';
      final path = 'staff_profiles/$userId-profile.${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      await Supabase.instance.client.storage.from('general').uploadBinary(
        path,
        _profileImageBytes!,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
      );
      
      return Supabase.instance.client.storage.from('general').getPublicUrl(path);
    } catch (e) {
      return _currentImageUrl;
    }
  }

  Future<void> _saveStaff() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final whatsapp = _whatsappController.text.trim();
    final isEditing = widget.editStaff != null;

    // Validación dinámica para indicar exactamente los campos faltantes
    final List<String> camposFaltantes = [];
    if (name.isEmpty) camposFaltantes.add('nombre');
    if (email.isEmpty) camposFaltantes.add('correo');
    if (password.isEmpty && !isEditing) camposFaltantes.add('contraseña');
    if (whatsapp.isEmpty) camposFaltantes.add('teléfono');

    if (camposFaltantes.isNotEmpty) {
      final String mensaje = 'Por favor completa: ${camposFaltantes.join(", ")}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String userId;
      if (isEditing) {
        userId = widget.editStaff!['userID'];
      } else {
        final authResponse = await Supabase.instance.client.auth.signUp(email: email, password: password);
        final user = authResponse.user;
        if (user == null) throw Exception('No se pudo crear la autenticación.');
        userId = user.id;
      }

      String? imageUrl = await _uploadProfileImage(userId);
      final firstActiveDay = _dailySchedules.firstWhere((day) => day['isActive'] == true, orElse: () => _dailySchedules[0]);

      // Update or Insert into users table
      final userData = {
        'nombre': name,
        'correo': email,
        'whatsapp': whatsapp,
        'sucursal': _selectedBranch,
        'isPersonal': _isPersonal,
        'isAdmin': _isAdmin,
        'isRecepcion': _isRecepcion,
        'isGestor': _isGestor,
        'IDEmpresa': 'FRFROIJNU821',
        if (password.isNotEmpty) 'password': password,
        if (_isPersonal) 'hora_entrada': _toDbTime(firstActiveDay['entrada']),
        if (_isPersonal) 'hora_salida': _toDbTime(firstActiveDay['salida']),
      };

      if (isEditing) {
        await Supabase.instance.client.from('users').update(userData).eq('IDUser', userId);
      } else {
        await Supabase.instance.client.from('users').insert({'IDUser': userId, ...userData});
      }

      // Update or Insert into Personal table (for all roles)
      final List<Map<String, dynamic>>? dbSchedule = _isPersonal
          ? _dailySchedules.map((day) {
              return {
                'dia': day['day'],
                'activo': day['isActive'],
                'entrada': _toDbTime(day['entrada']),
                'salida': _toDbTime(day['salida']),
                'descanso_inicio': _toDbTime(day['descanso_inicio']),
                'descanso_fin': _toDbTime(day['descanso_fin']),
              };
            }).toList()
          : null;

      final personalData = {
        'userID': userId,
        'nombre': name,
        'correo': email,
        'telefono': whatsapp,
        'sucursal': _selectedBranch,
        'foto_perfil': imageUrl,
        'mostrar_foto': _mostrarFoto,
        'servicios_ids': _isPersonal ? _selectedServiceIds : null,
        'tiene_certificado': _isPersonal ? _tieneCertificado : false,
        'certificado_nombre': (_isPersonal && _tieneCertificado) ? _certNombreController.text.trim() : null,
        'certificado_cedula': (_isPersonal && _tieneCertificado) ? _certCedulaController.text.trim() : null,
        'certificado_avalacion': (_isPersonal && _tieneCertificado) ? _certAvalacionController.text.trim() : null,
        'horarios': dbSchedule != null ? jsonEncode(dbSchedule) : null,
        'TipoPersonal': _selectedTipoPersonal,
        if (password.isNotEmpty) 'password': password,
      };

      final existingPersonal = await Supabase.instance.client
          .from('Personal')
          .select('userID')
          .eq('userID', userId)
          .maybeSingle();

      if (existingPersonal != null) {
        await Supabase.instance.client
            .from('Personal')
            .update(personalData)
            .eq('userID', userId);
      } else {
        await Supabase.instance.client
            .from('Personal')
            .insert(personalData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? '¡Personal actualizado!' : '¡Personal agregado!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editStaff != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Miembro' : 'Agregar Personal', 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Picture Section
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    backgroundImage: _profileImageBytes != null 
                        ? MemoryImage(_profileImageBytes!) 
                        : (_currentImageUrl != null ? NetworkImage(_currentImageUrl!) as ImageProvider : null),
                    child: _profileImageBytes == null && _currentImageUrl == null
                        ? const Icon(Icons.person_add_alt_1, size: 50, color: Colors.black26) 
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Mostrar foto en perfil público'),
                Switch(
                  value: _mostrarFoto,
                  onChanged: (val) => setState(() => _mostrarFoto = val),
                  activeColor: Colors.black,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Datos Personales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  CustomTextField(controller: _nameController, label: 'Nombre Completo', prefixIcon: Icons.person_outline),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _whatsappController, 
                    label: 'WhatsApp', 
                    prefixIcon: Icons.phone_android,
                    hint: 'Solo 10 dígitos',
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(controller: _emailController, label: 'Correo Electrónico', prefixIcon: Icons.email_outlined),
                  const SizedBox(height: 12),
                  if (!isEditing)
                    CustomTextField(controller: _passwordController, label: 'Contraseña Provisional', prefixIcon: Icons.lock_outline, obscureText: true),
                  if (!isEditing) const SizedBox(height: 16),
                  
                  // Sucursal Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 55,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
                    child: _isLoadingBranches
                        ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBranch,
                              hint: const Text('Sucursal Asignada'),
                              isExpanded: true,
                              items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                              onChanged: (val) => setState(() => _selectedBranch = val),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Tipo de Personal Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 55,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTipoPersonal,
                        hint: const Text('Rol del Miembro'),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'Barbero', child: Text('Barbero')),
                          DropdownMenuItem(value: 'Estilista', child: Text('Estilista')),
                          DropdownMenuItem(value: 'Gestor', child: Text('Gestor')),
                          DropdownMenuItem(value: 'Recepcionista', child: Text('Recepcionista')),
                          DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
                        ],
                        onChanged: (val) => setState(() => _selectedTipoPersonal = val),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isPersonal) ...[
              const SizedBox(height: 20),
              
              // Services Selection
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Servicios que Brinda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (_isLoadingServices)
                      const Center(child: CircularProgressIndicator(color: Colors.black))
                    else 
                      Wrap(
                        spacing: 8,
                        children: _services.map((service) {
                          final isSelected = _selectedServiceIds.contains(service['id']);
                          return FilterChip(
                            label: Text(service['nameService']),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedServiceIds.add(service['id']);
                                } else {
                                  _selectedServiceIds.remove(service['id']);
                                }
                              });
                            },
                            selectedColor: Colors.black.withOpacity(0.1),
                            checkmarkColor: Colors.black,
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              // Certificate Section (Switch local)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('¿Tiene Certificación?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Switch(
                          value: _tieneCertificado,
                          onChanged: (val) => setState(() => _tieneCertificado = val),
                          activeColor: Colors.black,
                        ),
                      ],
                    ),
                    if (_tieneCertificado) ...[
                      const SizedBox(height: 16),
                      CustomTextField(controller: _certNombreController, label: 'Nombre del Título', prefixIcon: Icons.badge_outlined),
                      const SizedBox(height: 12),
                      CustomTextField(controller: _certCedulaController, label: 'Cédula', prefixIcon: Icons.credit_card),
                      const SizedBox(height: 12),
                      CustomTextField(controller: _certAvalacionController, label: 'Avalación', prefixIcon: Icons.verified_user_outlined),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              
              // DAILY SCHEDULE SECTION (Google Maps Style)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Horario de Disponibilidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Configura los horarios específicos por día.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 20),
                    
                    ...List.generate(_dailySchedules.length, (index) {
                      final dayData = _dailySchedules[index];
                      final bool isActive = dayData['isActive'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(dayData['day'], style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.black38)),
                                ),
                                Switch(
                                  value: isActive,
                                  onChanged: (val) => setState(() => dayData['isActive'] = val),
                                  activeColor: Colors.black,
                                ),
                                const Spacer(),
                                if (!isActive)
                                  const Text('Cerrado', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600))
                                else
                                  Row(
                                    children: [
                                      _timeButton(index, 'entrada', dayData['entrada']),
                                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('-')),
                                      _timeButton(index, 'salida', dayData['salida']),
                                    ],
                                  ),
                              ],
                            ),
                            if (isActive) 
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 90),
                                child: Row(
                                  children: [
                                    const Icon(Icons.coffee_outlined, size: 14, color: Colors.black45),
                                    const SizedBox(width: 8),
                                    const Text('Break: ', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                    _timeButton(index, 'descanso_inicio', dayData['descanso_inicio'], small: true),
                                    const Text(' - ', style: TextStyle(fontSize: 11)),
                                    _timeButton(index, 'descanso_fin', dayData['descanso_fin'], small: true),
                                  ],
                                ),
                              ),
                            const Divider(height: 24),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveStaff,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(isEditing ? 'Guardar Cambios' : 'Registrar Nuevo Miembro', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _timeButton(int dayIndex, String field, TimeOfDay? time, {bool small = false}) {
    return InkWell(
      onTap: () => _pickTimeForDay(dayIndex, field),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 4 : 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12, width: 0.5),
        ),
        child: Text(
          _formatTime(time),
          style: TextStyle(
            fontSize: small ? 11 : 14,
            fontWeight: FontWeight.bold,
            color: time == null ? Colors.black38 : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _whatsappController.dispose();
    _certNombreController.dispose();
    _certCedulaController.dispose();
    _certAvalacionController.dispose();
    super.dispose();
  }
}

