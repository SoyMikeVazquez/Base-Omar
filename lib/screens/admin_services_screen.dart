import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_text_field.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Services')
          .select()
          .order('nameService', ascending: true);
      setState(() => _services = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar servicios: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteService(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Servicio'),
        content: const Text('¿Estás seguro de que deseas eliminar este servicio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await _supabase.from('Services').delete().eq('id', id);
      _fetchServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _openForm([Map<String, dynamic>? service]) {
    showDialog(
      context: context,
      builder: (ctx) => _ServiceFormDialog(service: service, onSaved: _fetchServices),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Administrar Servicios',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Nuevo', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_services.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('No hay servicios registrados.', style: TextStyle(color: Colors.black54)),
                    ),
                  )
                else
                  ..._services.map((s) => _ServiceCard(
                        service: s,
                        onEdit: () => _openForm(s),
                        onDelete: () => _deleteService(s['id']),
                      )),
              ],
            ),
          );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard({required this.service, required this.onEdit, required this.onDelete});

  String _formatDuration(int? minutes) {
    if (minutes == null) return 'N/A';
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = service['ImageService'];
    final price = service['Price'];
    final pricePremium = service['PrecioPremium'];
    final duration = service['tiempo_servicio'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: (imageUrl != null && imageUrl.toString().isNotEmpty)
                ? Image.network(imageUrl, width: 110, height: 110, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['nameService'] ?? 'Sin Nombre',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service['descriptionService'] ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (price != null)
                        _Chip(label: '\$$price', icon: Icons.attach_money),
                      if (pricePremium != null) ...[
                        const SizedBox(width: 6),
                        _Chip(label: '\$$pricePremium ✦', icon: Icons.star_outline, isPremium: true),
                      ],
                      if (duration != null) ...[
                        const SizedBox(width: 6),
                        _Chip(label: _formatDuration(duration), icon: Icons.timer_outlined),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Actions
          Column(
            children: [
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.black87, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 110,
        height: 110,
        color: Colors.grey[200],
        child: const Icon(Icons.spa_outlined, size: 36, color: Colors.black26),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPremium;
  const _Chip({required this.label, required this.icon, this.isPremium = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium ? Colors.amber.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: isPremium ? Border.all(color: Colors.amber.shade700, width: 0.5) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isPremium ? Colors.amber.shade800 : Colors.black87,
        ),
      ),
    );
  }
}

// ─── Form Dialog ────────────────────────────────────────────────────────────

class _ServiceFormDialog extends StatefulWidget {
  final Map<String, dynamic>? service;
  final VoidCallback onSaved;
  const _ServiceFormDialog({this.service, required this.onSaved});

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceStdCtrl  = TextEditingController(); // Price  → Estándar
  final _priceHighCtrl = TextEditingController(); // Prince2 → Elevado
  final _pricePreCtrl  = TextEditingController(); // Price3  → Premium

  int _durationMinutes = 30;
  XFile? _mainImageFile;
  Uint8List? _mainImageBytes; // for web-compatible preview
  String? _mainImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    if (s != null) {
      _nameCtrl.text     = s['nameService'] ?? '';
      _descCtrl.text     = s['descriptionService'] ?? '';
      _priceStdCtrl.text  = (s['Price']   ?? '').toString();
      _priceHighCtrl.text = (s['Prince2'] ?? '').toString();
      _pricePreCtrl.text  = (s['Price3']  ?? '').toString();
      _durationMinutes    = s['tiempo_servicio'] ?? 30;
      _mainImageUrl       = s['ImageService'];
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _mainImageFile  = file;
        _mainImageBytes = bytes;
      });
    }
  }



  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del servicio es obligatorio.')),
      );
      return;
    }
    setState(() => _isUploading = true);

    try {
      final isNew = widget.service == null;
      final serviceId = isNew
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.service!['IDServices'] ?? widget.service!['id'];

      String? mainUrl = _mainImageUrl;
      if (_mainImageFile != null && _mainImageBytes != null) {
        mainUrl = await _uploadImage(_mainImageFile!, _mainImageBytes!, serviceId);
      }

      num? parseNum(String v) => v.trim().isEmpty ? null : num.tryParse(v.trim());

      final data = <String, dynamic>{
        'nameService':        _nameCtrl.text.trim(),
        'descriptionService': _descCtrl.text.trim(),
        'Price':              parseNum(_priceStdCtrl.text),
        'Prince2':            parseNum(_priceHighCtrl.text),
        'Price3':             parseNum(_pricePreCtrl.text),
        'tiempo_servicio':    _durationMinutes,
        'updated_at':         DateTime.now().toIso8601String(),
        if (mainUrl != null) 'ImageService': mainUrl,
      };

      if (isNew) {
        data['IDServices'] = serviceId;
        await Supabase.instance.client.from('Services').insert(data);
      } else {
        await Supabase.instance.client
            .from('Services')
            .update(data)
            .eq('id', widget.service!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isUploading = false);
      }
    }
  }

  Future<String> _uploadImage(XFile file, Uint8List bytes, String serviceId) async {
    final ext = file.name.split('.').last;
    final path = 'services/$serviceId-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await Supabase.instance.client.storage.from('general').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
    return Supabase.instance.client.storage.from('general').getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.service == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.spa_outlined, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isNew ? 'Nuevo Servicio' : 'Editar Servicio',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Image picker ──────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: _mainImageBytes != null
                        ? Image.memory(_mainImageBytes!, fit: BoxFit.cover)
                        : (_mainImageUrl != null && _mainImageUrl!.isNotEmpty)
                            ? Image.network(_mainImageUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imagePlaceholder())
                            : _imagePlaceholder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(_mainImageBytes != null || (_mainImageUrl != null && _mainImageUrl!.isNotEmpty)
                        ? 'Cambiar imagen'
                        : 'Subir imagen principal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Basic info ────────────────────────────────────────────
                CustomTextField(controller: _nameCtrl, label: 'Nombre del Servicio', prefixIcon: Icons.spa_outlined),
                const SizedBox(height: 12),
                CustomTextField(controller: _descCtrl, label: 'Descripción', prefixIcon: Icons.description_outlined, maxLines: 3),
                const SizedBox(height: 16),

                // ── Duration picker ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.black54, size: 20),
                      const SizedBox(width: 12),
                      const Text('Duración del servicio', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() { if (_durationMinutes > 5) _durationMinutes -= 5; }),
                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _formatDuration(_durationMinutes),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _durationMinutes += 5),
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Pricing ───────────────────────────────────────────────
                const Text('Precios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text(
                  'Asigna a cada sucursal un nivel (1-2-3) para determinar qué precio se aplica.',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 10),
                CustomTextField(controller: _priceStdCtrl,  label: 'Precio Estándar  (Nivel 1)', prefixIcon: Icons.attach_money),
                const SizedBox(height: 10),
                CustomTextField(controller: _priceHighCtrl, label: 'Precio Elevado   (Nivel 2)', prefixIcon: Icons.attach_money),
                const SizedBox(height: 10),
                CustomTextField(controller: _pricePreCtrl,  label: 'Precio Premium   (Nivel 3)', prefixIcon: Icons.star_outline),
                const SizedBox(height: 24),

                // ── Actions ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _save,
                        child: _isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Guardar'),
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
  }

  Widget _imagePlaceholder() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 38, color: Colors.black38),
          SizedBox(height: 6),
          Text('Sin imagen', style: TextStyle(color: Colors.black38)),
        ],
      );

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceStdCtrl.dispose();
    _priceHighCtrl.dispose();
    _pricePreCtrl.dispose();
    super.dispose();
  }
}
