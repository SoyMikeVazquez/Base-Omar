import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/custom_text_field.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Eventos')
          .select()
          .order('created_at', ascending: false);
      setState(() => _events = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEventDialog([Map<String, dynamic>? event]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventFormDialog(
        event: event,
        onSaved: () {
          Navigator.pop(context);
          _fetchEvents();
        },
      ),
    );
  }

  Future<void> _deleteEvent(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Evento'),
        content: const Text('¿Estás seguro de que deseas eliminar este evento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('Eventos').delete().eq('id', id);
      _fetchEvents();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              onRefresh: _fetchEvents,
              color: Colors.black,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gestión de Eventos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text('Anuncios y promociones principales', style: TextStyle(color: Colors.black54, fontSize: 13)),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showEventDialog(),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Nuevo', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_events.isEmpty)
                    const SliverFillRemaining(child: Center(child: Text('No hay eventos registrados')))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final e = _events[index];
                            return _EventCard(
                              event: e,
                              onEdit: () => _showEventDialog(e),
                              onDelete: () => _deleteEvent(e['id']),
                            );
                          },
                          childCount: _events.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({required this.event, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final image = event['imagenDeEvento'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null && image.toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: CachedNetworkImage(
                imageUrl: image,
                height: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 150,
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.black12),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['TituloDeEvento'] ?? 'Sin Título', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(event['DescripcionDelEvento'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 8),
                      Text('ID: ${event['IDdeEvento'] ?? '---'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black26)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventFormDialog extends StatefulWidget {
  final Map<String, dynamic>? event;
  final VoidCallback onSaved;

  const _EventFormDialog({this.event, required this.onSaved});

  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _fechaEvento;
  DateTime? _fechaFin;
  DateTime? _fechaOcultar;
  String? _imageUrl;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!['TituloDeEvento'] ?? '';
      _descController.text = widget.event!['DescripcionDelEvento'] ?? '';
      _imageUrl = widget.event!['imagenDeEvento'];
      if (widget.event!['FechaDeEvento'] != null) _fechaEvento = DateTime.parse(widget.event!['FechaDeEvento']);
      if (widget.event!['FechaEnQueFinalizà'] != null) _fechaFin = DateTime.parse(widget.event!['FechaEnQueFinalizà']);
      if (widget.event!['FechaYaNoVerNuevoEvento'] != null) _fechaOcultar = DateTime.parse(widget.event!['FechaYaNoVerNuevoEvento']);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final path = 'events/${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      await Supabase.instance.client.storage.from('general').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/$ext'));
      final url = Supabase.instance.client.storage.from('general').getPublicUrl(path);
      setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickDate(String field) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() {
        if (field == 'evento') _fechaEvento = date;
        if (field == 'fin') _fechaFin = date;
        if (field == 'ocultar') _fechaOcultar = date;
      });
    }
  }

  String _generateRandomID() {
    final random = Random();
    return (10000 + random.nextInt(90000)).toString();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'TituloDeEvento': _titleController.text.trim(),
        'DescripcionDelEvento': _descController.text.trim(),
        'imagenDeEvento': _imageUrl,
        'FechaDeEvento': _fechaEvento?.toIso8601String(),
        'FechaEnQueFinalizà': _fechaFin?.toIso8601String(),
        'FechaYaNoVerNuevoEvento': _fechaOcultar?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.event == null) {
        data['IDdeEvento'] = _generateRandomID();
        await Supabase.instance.client.from('Eventos').insert(data);
      } else {
        await Supabase.instance.client.from('Eventos').update(data).eq('id', widget.event!['id']);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.event == null ? 'Nuevo Evento' : 'Editar Evento', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 20),
            
            // Image Picker
            GestureDetector(
              onTap: _isSaving || _isUploadingImage ? null : _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imageUrl != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(color: Colors.black),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.broken_image, size: 40, color: Colors.black26),
                            ),
                          ),
                        ),
                      )
                    else if (!_isUploadingImage)
                      const Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.black26),
                    
                    if (_isUploadingImage)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Al presionar el botón de la imagen podrás subir de nuevo tu imagen para actualizar la portada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),

            CustomTextField(controller: _titleController, label: 'Título del Evento', prefixIcon: Icons.title),
            const SizedBox(height: 16),
            CustomTextField(controller: _descController, label: 'Descripción', prefixIcon: Icons.description, maxLines: 3),
            const SizedBox(height: 20),

            const Text('Fechas Importantes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _dateTile('Fecha del Evento', _fechaEvento, () => _pickDate('evento')),
            _dateTile('Fecha que Finaliza', _fechaFin, () => _pickDate('fin')),
            _dateTile('Dejar de Mostrar', _fechaOcultar, () => _pickDate('ocultar')),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: (_isSaving || _isUploadingImage) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.event == null ? 'Crear Evento' : 'Guardar Cambios', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(date == null ? 'No seleccionada' : '${date.day}/${date.month}/${date.year}', style: TextStyle(color: date == null ? Colors.black26 : Colors.black, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.calendar_month_outlined, size: 20),
      onTap: onTap,
    );
  }
}
