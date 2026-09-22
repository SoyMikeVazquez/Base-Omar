import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../widgets/custom_text_field.dart';

class GeneralConfigScreen extends StatefulWidget {
  const GeneralConfigScreen({super.key});

  @override
  State<GeneralConfigScreen> createState() => _GeneralConfigScreenState();
}

class _GeneralConfigScreenState extends State<GeneralConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _rowId;

  // Controllers for general configurations
  final _nombreEmpresaCtrl = TextEditingController();
  final _giroCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _recompensaTituloCtrl = TextEditingController();
  final _recompensaDescCtrl = TextEditingController();
  final _soporteCtrl = TextEditingController();
  final _politicaCtrl = TextEditingController();
  final _correoNotificacionesGeneralCtrl = TextEditingController();

  // Boolean settings
  bool _verPreciosProductos = false;
  bool _verPreciosServicios = false;
  bool _elimCuenta = false;

  // Images state
  XFile? _logoFile;
  Uint8List? _logoBytes;
  String? _logoUrl;
  bool _logoDeleted = false;

  XFile? _portadaFile;
  Uint8List? _portadaBytes;
  String? _portadaUrl;
  bool _portadaDeleted = false;

  // Video state
  XFile? _videoFile;
  Uint8List? _videoBytes;
  String? _videoUrl;
  bool _videoDeleted = false;
  double? _videoSizeMb;

  @override
  void initState() {
    super.initState();
    _fetchGeneral();
  }

  Future<void> _fetchGeneral() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('General')
          .select()
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _rowId = response['id'];
        _nombreEmpresaCtrl.text = response['NombreDeLaEmpresa'] ?? '';
        _giroCtrl.text = response['Giro'] ?? '';
        _puntosCtrl.text = (response['PUNTOSALCOMPLETAR'] ?? 6).toString();
        _recompensaTituloCtrl.text = response['RecompensaTituloPuntos'] ?? '';
        _recompensaDescCtrl.text = response['RecompensaDescripcionPuntos'] ?? '';
        _soporteCtrl.text = response['Soporte'] ?? '';
        _politicaCtrl.text = response['PoliticaDePrivacidad'] ?? '';
        _correoNotificacionesGeneralCtrl.text = response['correoNotificacionesGeneral'] ?? '';

        _verPreciosProductos = response['verPreciosProductos'] ?? false;
        _verPreciosServicios = response['verPreciosServicios'] ?? false;
        _elimCuenta = response['ElimCuenta'] ?? false;

        _logoUrl = response['LogoDeLaEmpresa'];
        _portadaUrl = response['imagePortada'];
        _videoUrl = response['urlVideo'];

        _logoFile = null;
        _logoBytes = null;
        _logoDeleted = false;

        _portadaFile = null;
        _portadaBytes = null;
        _portadaDeleted = false;

        _videoFile = null;
        _videoBytes = null;
        _videoDeleted = false;
        _videoSizeMb = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar configuración: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _logoFile = file;
        _logoBytes = bytes;
        _logoDeleted = false;
      });
    }
  }

  void _deleteLogo() {
    setState(() {
      _logoFile = null;
      _logoBytes = null;
      _logoUrl = null;
      _logoDeleted = true;
    });
  }

  Future<void> _pickPortada() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _portadaFile = file;
        _portadaBytes = bytes;
        _portadaDeleted = false;
      });
    }
  }

  void _deletePortada() {
    setState(() {
      _portadaFile = null;
      _portadaBytes = null;
      _portadaUrl = null;
      _portadaDeleted = true;
    });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      // Show loading overlay or state so user knows validation is running
      setState(() => _isSaving = true);
      
      try {
        // 1. Validate File Size
        final sizeInBytes = await file.length();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        
        if (sizeInMB > 40) {
          _showWarningDialog(
            'Video muy pesado',
            'El video seleccionado pesa ${sizeInMB.toStringAsFixed(1)}MB. '
            'El peso máximo permitido es de 40MB para garantizar una descarga fluida.',
          );
          return;
        }

        // Passed all validations
        final bytes = await file.readAsBytes();
        setState(() {
          _videoFile = file;
          _videoBytes = bytes;
          _videoSizeMb = sizeInMB;
          _videoDeleted = false;
        });
      } catch (e) {
        debugPrint('Error validating video size: $e');
        _showWarningDialog(
          'Error de validación',
          'No se pudo verificar el archivo de video. Por favor, asegúrate de que sea un archivo de video válido.',
        );
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showWarningDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Entendido', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteVideo() {
    setState(() {
      _videoFile = null;
      _videoBytes = null;
      _videoUrl = null;
      _videoDeleted = true;
      _videoSizeMb = null;
    });
  }

  Future<String> _uploadFile(XFile file, Uint8List bytes, String folder) async {
    final ext = file.name.split('.').last;
    final path = '$folder/${folder}-${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    // Choose appropriate Content-Type
    String contentType = 'application/octet-stream';
    if (folder == 'logo' || folder == 'portada') {
      contentType = 'image/$ext';
    } else if (folder == 'videos') {
      contentType = 'video/$ext';
    }

    await Supabase.instance.client.storage.from('general').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return Supabase.instance.client.storage.from('general').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (_nombreEmpresaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de la empresa es obligatorio.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      // 1. Upload Logo if added
      String? finalLogoUrl = _logoUrl;
      if (_logoDeleted) {
        finalLogoUrl = null;
      } else if (_logoFile != null && _logoBytes != null) {
        finalLogoUrl = await _uploadFile(_logoFile!, _logoBytes!, 'logo');
      }

      // 2. Upload Portada if added
      String? finalPortadaUrl = _portadaUrl;
      if (_portadaDeleted) {
        finalPortadaUrl = null;
      } else if (_portadaFile != null && _portadaBytes != null) {
        finalPortadaUrl = await _uploadFile(_portadaFile!, _portadaBytes!, 'portada');
      }

      // 3. Upload Video if added
      String? finalVideoUrl = _videoUrl;
      if (_videoDeleted) {
        finalVideoUrl = null;
      } else if (_videoFile != null && _videoBytes != null) {
        finalVideoUrl = await _uploadFile(_videoFile!, _videoBytes!, 'videos');
      }

      final data = {
        'NombreDeLaEmpresa': _nombreEmpresaCtrl.text.trim(),
        'Giro': _giroCtrl.text.trim(),
        'LogoDeLaEmpresa': finalLogoUrl,
        'imagePortada': finalPortadaUrl,
        'urlVideo': finalVideoUrl,
        'PUNTOSALCOMPLETAR': int.tryParse(_puntosCtrl.text) ?? 6,
        'RecompensaTituloPuntos': _recompensaTituloCtrl.text.trim(),
        'RecompensaDescripcionPuntos': _recompensaDescCtrl.text.trim(),
        'Soporte': _soporteCtrl.text.trim().isEmpty ? null : _soporteCtrl.text.trim(),
        'PoliticaDePrivacidad': _politicaCtrl.text.trim().isEmpty ? null : _politicaCtrl.text.trim(),
        'correoNotificacionesGeneral': _correoNotificacionesGeneralCtrl.text.trim().isEmpty ? null : _correoNotificacionesGeneralCtrl.text.trim(),
        'verPreciosProductos': _verPreciosProductos,
        'verPreciosServicios': _verPreciosServicios,
        'ElimCuenta': _elimCuenta,
      };

      if (_rowId != null) {
        await Supabase.instance.client
            .from('General')
            .update(data)
            .eq('id', _rowId!);
      } else {
        await Supabase.instance.client
            .from('General')
            .insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada exitosamente.'),
            backgroundColor: Colors.black,
          ),
        );
        _fetchGeneral();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar configuración: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 20),
          _buildBusinessIdentityCard(),
          const SizedBox(height: 16),
          _buildLoyaltyCard(),
          const SizedBox(height: 16),
          _buildPriceVisibilityCard(),
          const SizedBox(height: 16),
          _buildPoliciesAndSupportCard(),
          const SizedBox(height: 16),
          _buildSystemTogglesCard(),
          const SizedBox(height: 30),
          _buildActionButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Configuración General',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Personaliza las reglas de tu negocio, fidelización e imágenes.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildBusinessIdentityCard() {
    final hasVideo = _videoBytes != null || (_videoUrl != null && _videoUrl!.isNotEmpty);

    return _buildCardContainer(
      children: [
        _buildSectionHeader('Identidad del Negocio', Icons.storefront_outlined),
        CustomTextField(
          controller: _nombreEmpresaCtrl,
          label: 'Nombre de la Empresa',
          prefixIcon: Icons.business_outlined,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _giroCtrl,
          label: 'Giro del Negocio',
          prefixIcon: Icons.category_outlined,
        ),
        const SizedBox(height: 20),

        // ── Logo uploader block ──
        const Text(
          'Logo de la Empresa',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 80,
                width: 80,
                color: Colors.grey[100],
                child: _logoBytes != null
                    ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                    : (_logoUrl != null && _logoUrl!.isNotEmpty)
                        ? Image.network(
                            _logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _logoPlaceholder(),
                          )
                        : _logoPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.photo_library_outlined, size: 16, color: Colors.black87),
                    label: const Text('Subir Logo', style: TextStyle(color: Colors.black87, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_logoBytes != null || (_logoUrl != null && _logoUrl!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: TextButton.icon(
                        onPressed: _deleteLogo,
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        label: const Text('Eliminar', style: TextStyle(color: Colors.red, fontSize: 12)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Portada uploader block ──
        const Text(
          'Imagen de Portada',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 140,
            width: double.infinity,
            color: Colors.grey[100],
            child: _portadaBytes != null
                ? Image.memory(_portadaBytes!, fit: BoxFit.cover)
                : (_portadaUrl != null && _portadaUrl!.isNotEmpty)
                    ? Image.network(
                        _portadaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _portadaPlaceholder(),
                      )
                    : _portadaPlaceholder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickPortada,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16, color: Colors.black87),
              label: const Text('Subir Portada', style: TextStyle(color: Colors.black87, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (_portadaBytes != null || (_portadaUrl != null && _portadaUrl!.isNotEmpty)) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _deletePortada,
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Eliminar Portada', style: TextStyle(color: Colors.red, fontSize: 12)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),

        // ── Video de Inicio block ──
        const Text(
          'Video de Inicio',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        const Text(
          'El video debe ser de un formato válido. Máximo: 40MB.',
          style: TextStyle(fontSize: 11, color: Colors.black45),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasVideo ? Colors.black.withOpacity(0.04) : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasVideo ? Colors.black12 : Colors.grey[300]!,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasVideo ? Colors.black.withOpacity(0.08) : Colors.black12,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasVideo ? Icons.play_circle_fill_outlined : Icons.videocam_outlined,
                  color: hasVideo ? Colors.black87 : Colors.black38,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasVideo ? 'Video seleccionado' : 'Sin video cargado',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _videoSizeMb != null
                          ? 'Nuevo video: ${_videoSizeMb!.toStringAsFixed(1)}MB'
                          : (_videoUrl != null && _videoUrl!.isNotEmpty)
                              ? 'Video activo en el servidor'
                              : 'Subir un video corto',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (hasVideo)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _deleteVideo,
                  tooltip: 'Eliminar video',
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _pickVideo,
          icon: const Icon(Icons.movie_outlined, size: 16, color: Colors.black87),
          label: const Text('Seleccionar Video', style: TextStyle(color: Colors.black87, fontSize: 12)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _logoPlaceholder() => Container(
        color: Colors.grey[100],
        child: const Icon(Icons.storefront, size: 36, color: Colors.black26),
      );

  Widget _portadaPlaceholder() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.landscape_outlined, size: 40, color: Colors.black26),
          SizedBox(height: 6),
          Text('Sin imagen de portada', style: TextStyle(color: Colors.black26, fontSize: 12)),
        ],
      );

  Widget _buildLoyaltyCard() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader('Tarjeta de Fidelidad & Recompensas', Icons.stars_outlined),
        CustomTextField(
          controller: _puntosCtrl,
          label: 'Número de Estrellas a Completar',
          prefixIcon: Icons.star_border_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _recompensaTituloCtrl,
          label: 'Título del Premio',
          prefixIcon: Icons.card_giftcard_outlined,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _recompensaDescCtrl,
          label: 'Descripción del Premio',
          prefixIcon: Icons.description_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildPriceVisibilityCard() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader('Visibilidad de Precios (Clientes)', Icons.visibility_outlined),
        const Text(
          'Personaliza qué precios son visibles para tus clientes en la aplicación principal y en la reserva de citas.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        _buildSwitchTile(
          title: 'Mostrar Precios de Servicios',
          subtitle: 'Permite a los clientes ver los precios de los servicios',
          value: _verPreciosServicios,
          onChanged: (val) => setState(() => _verPreciosServicios = val),
        ),
        const Divider(height: 16),
        _buildSwitchTile(
          title: 'Mostrar Precios de Productos',
          subtitle: 'Permite a los clientes ver los precios de los productos',
          value: _verPreciosProductos,
          onChanged: (val) => setState(() => _verPreciosProductos = val),
        ),
      ],
    );
  }

  Widget _buildPoliciesAndSupportCard() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader('Soporte, Políticas y Alertas', Icons.policy_outlined),
        CustomTextField(
          controller: _correoNotificacionesGeneralCtrl,
          label: 'Correo de Notificaciones General (Todas las citas)',
          prefixIcon: Icons.mark_as_unread_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _soporteCtrl,
          label: 'Enlace / Contacto de Soporte',
          prefixIcon: Icons.support_agent_outlined,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _politicaCtrl,
          label: 'Política de Privacidad (Contenido o URL)',
          prefixIcon: Icons.lock_outline_rounded,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSystemTogglesCard() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader('Controles del Sistema', Icons.settings_applications_outlined),
        _buildSwitchTile(
          title: 'Permitir Eliminar Cuenta',
          subtitle: 'Muestra a los clientes la opción para borrar su cuenta',
          value: _elimCuenta,
          onChanged: (val) => setState(() => _elimCuenta = val),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      activeColor: Colors.black,
      activeTrackColor: Colors.black87,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Guardar Configuración',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreEmpresaCtrl.dispose();
    _giroCtrl.dispose();
    _puntosCtrl.dispose();
    _recompensaTituloCtrl.dispose();
    _recompensaDescCtrl.dispose();
    _soporteCtrl.dispose();
    _politicaCtrl.dispose();
    _correoNotificacionesGeneralCtrl.dispose();
    super.dispose();
  }
}
