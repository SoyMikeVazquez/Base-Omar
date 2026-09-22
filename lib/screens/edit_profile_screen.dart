import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/session_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _currentImageUrl;
  Uint8List? _newImageBytes;
  XFile? _newImageFile;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      if (session.userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final table = session.isStaff ? 'users' : 'clientes';
      final idColumn = session.isStaff ? 'IDUser' : 'IDCliente';

      var query = Supabase.instance.client.from(table).select();
      
      if (session.userId != null) {
        query = query.eq(idColumn, session.userId!);
      } else if (session.userEmail != null) {
        query = query.eq('correo', session.userEmail!);
      } else {
        setState(() => _isLoading = false);
        return;
      }

      final response = await query.single();

      if (mounted) {
        setState(() {
          _nameController.text = response['nombre'] ?? '';
          _emailController.text = response['correo'] ?? '';
          _phoneController.text = response['telefono'] ?? response['whatsapp'] ?? '';
          _currentImageUrl = response['fotoperfil'] ?? response['foto_perfil'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    bool isGranted = false;
    try {
      final status = await Permission.photos.request();
      isGranted = status.isGranted || status.isLimited;
    } catch (e) {
      debugPrint('Photos request failed, falling back: $e');
      isGranted = true; // Fallback to let ImagePicker handle it natively
    }

    if (isGranted) {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _newImageFile = file;
          _newImageBytes = bytes;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de Galería denegado. Actívalo en los ajustes del sistema.'),
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_newImageBytes == null || _newImageFile == null) return _currentImageUrl;

    try {
      final fileExt = _newImageFile!.name.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'profiles/$fileName';

      await Supabase.instance.client.storage.from('general').uploadBinary(
            path,
            _newImageBytes!,
            fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
          );

      return Supabase.instance.client.storage.from('general').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return _currentImageUrl;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim();
      
      final imageUrl = await _uploadImage(session.userId!);

      final table = session.isStaff ? 'users' : 'clientes';
      final idColumn = session.isStaff ? 'IDUser' : 'IDCliente';
      final phoneColumn = session.isStaff ? 'whatsapp' : 'telefono';

      await Supabase.instance.client.from(table).update({
        'nombre': newName,
        phoneColumn: newPhone,
        if (imageUrl != null) 'fotoperfil': imageUrl,
      }).eq(idColumn, session.userId!);

      // Also update Personal table if staff
      if (session.isStaff) {
        try {
          await Supabase.instance.client.from('Personal').update({
            'nombre': newName,
            'telefono': newPhone,
            'foto_perfil': imageUrl,
          }).eq('userID', session.userId!);
        } catch (_) {}
      }

      // Update Session Provider
      await session.updateClientData(
        name: newName,
        email: session.userEmail ?? '', // Keep existing email in session
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado con éxito')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Editar Perfil',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo Picker
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.black12,
                            backgroundImage: _newImageBytes != null
                                ? MemoryImage(_newImageBytes!)
                                : (_currentImageUrl != null
                                    ? NetworkImage(_currentImageUrl!) as ImageProvider
                                    : null),
                            child: _newImageBytes == null && _currentImageUrl == null
                                ? const Icon(Icons.person, size: 60, color: Colors.black26)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    const Text(
                      'Actualiza tu información personal',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Nombre Completo',
                      icon: Icons.person_outline,
                      validator: (v) => v!.isEmpty ? 'Ingresa tu nombre' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Teléfono',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      hintText: 'Solo 10 dígitos',
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => v!.isEmpty ? 'Ingresa tu teléfono' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Correo Electrónico',
                      icon: Icons.email_outlined,
                      readOnly: true,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'El correo no se puede editar por el momento.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Guardar Cambios',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    int? maxLength,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        counterText: '',
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.withOpacity(0.05) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
    );
  }
}

