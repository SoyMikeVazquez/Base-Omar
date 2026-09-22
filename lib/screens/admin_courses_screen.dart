import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_text_field.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Cursos')
          .select()
          .order('created_at', ascending: false);
      setState(() => _courses = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCourseDialog([Map<String, dynamic>? course]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CourseFormDialog(
        course: course,
        onSaved: () {
          Navigator.pop(context);
          _fetchCourses();
        },
      ),
    );
  }

  Future<void> _deleteCourse(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Curso'),
        content: const Text('¿Estás seguro de que deseas eliminar este curso?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('Cursos').delete().eq('id', id);
      _fetchCourses();
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
              onRefresh: _fetchCourses,
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
                              Text('Gestión de Cursos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text('Administra tus programas educativos', style: TextStyle(color: Colors.black54, fontSize: 13)),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showCourseDialog(),
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
                  if (_courses.isEmpty)
                    const SliverFillRemaining(child: Center(child: Text('No hay cursos registrados')))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final c = _courses[index];
                            return _CourseCard(
                              course: c,
                              onEdit: () => _showCourseDialog(c),
                              onDelete: () => _deleteCourse(c['id']),
                            );
                          },
                          childCount: _courses.length,
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

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CourseCard({required this.course, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final image = course['ImagenPortada'];
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(image, height: 140, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50)),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                    child: Text('\$${course['PrecioFinal']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course['NombreDelCurso'] ?? 'Sin Nombre', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(course['DescripcionCorta'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: (course['isDisponible'] ?? true) ? Colors.green : Colors.red),
                          const SizedBox(width: 4),
                          Text((course['isDisponible'] ?? true) ? 'Disponible' : 'Privado', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                        ],
                      ),
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

class _CourseFormDialog extends StatefulWidget {
  final Map<String, dynamic>? course;
  final VoidCallback onSaved;

  const _CourseFormDialog({this.course, required this.onSaved});

  @override
  State<_CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<_CourseFormDialog> {
  final _nameController = TextEditingController();
  final _descShortController = TextEditingController();
  final _descLongController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _anticipoController = TextEditingController();
  final _pagoController = TextEditingController();
  
  bool _isAvailable = true;
  DateTime? _fechaInicio;
  String? _imageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.course != null) {
      _nameController.text = widget.course!['NombreDelCurso'] ?? '';
      _descShortController.text = widget.course!['DescripcionCorta'] ?? '';
      _descLongController.text = widget.course!['DescripcionLarga'] ?? '';
      _priceController.text = (widget.course!['PrecioFinal'] ?? 0).toString();
      _discountController.text = (widget.course!['Descuento'] ?? 0).toString();
      _anticipoController.text = (widget.course!['Anticipo'] ?? 0).toString();
      _pagoController.text = widget.course!['DatosDePago'] ?? '';
      _isAvailable = widget.course!['isDisponible'] ?? true;
      _imageUrl = widget.course!['ImagenPortada'];
      if (widget.course!['FechaDelInicio'] != null) _fechaInicio = DateTime.parse(widget.course!['FechaDelInicio']);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final path = 'courses/${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      await Supabase.instance.client.storage.from('general').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/$ext'));
      final url = Supabase.instance.client.storage.from('general').getPublicUrl(path);
      setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) setState(() => _fechaInicio = date);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'NombreDelCurso': _nameController.text.trim(),
        'DescripcionCorta': _descShortController.text.trim(),
        'DescripcionLarga': _descLongController.text.trim(),
        'ImagenPortada': _imageUrl,
        'PrecioFinal': double.tryParse(_priceController.text) ?? 0,
        'Descuento': double.tryParse(_discountController.text) ?? 0,
        'Anticipo': double.tryParse(_anticipoController.text) ?? 0,
        'DatosDePago': _pagoController.text.trim(),
        'isDisponible': _isAvailable,
        'FechaDelInicio': _fechaInicio?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.course == null) {
        await Supabase.instance.client.from('Cursos').insert(data);
      } else {
        await Supabase.instance.client.from('Cursos').update(data).eq('id', widget.course!['id']);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                Text(widget.course == null ? 'Nuevo Curso' : 'Editar Curso', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 20),
            
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
                child: _imageUrl != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(_imageUrl!, fit: BoxFit.cover))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.black26), Text('Imagen Portada', style: TextStyle(color: Colors.black26, fontSize: 12))]),
              ),
            ),
            const SizedBox(height: 20),

            CustomTextField(controller: _nameController, label: 'Nombre del Curso', prefixIcon: Icons.book_outlined),
            const SizedBox(height: 12),
            CustomTextField(controller: _descShortController, label: 'Resumen Corto', prefixIcon: Icons.short_text),
            const SizedBox(height: 12),
            CustomTextField(controller: _descLongController, label: 'Descripción Detallada', prefixIcon: Icons.notes, maxLines: 4),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: CustomTextField(controller: _priceController, label: 'Precio Final', prefixIcon: Icons.attach_money, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: CustomTextField(controller: _anticipoController, label: 'Anticipo', prefixIcon: Icons.payments_outlined, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 12),
            CustomTextField(controller: _discountController, label: 'Descuento (%)', prefixIcon: Icons.percent, keyboardType: TextInputType.number),
            const SizedBox(height: 20),

            const Text('Configuración Adicional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de Inicio'),
              subtitle: Text(_fechaInicio == null ? 'No seleccionada' : '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: _pickDate,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Curso Disponible'),
              subtitle: const Text('Hacer visible para los clientes'),
              value: _isAvailable,
              activeColor: Colors.black,
              onChanged: (v) => setState(() => _isAvailable = v),
            ),
            const SizedBox(height: 12),
            CustomTextField(controller: _pagoController, label: 'Datos de Pago (Instrucciones)', prefixIcon: Icons.payment, maxLines: 2),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.course == null ? 'Crear Programa' : 'Guardar Cambios', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
