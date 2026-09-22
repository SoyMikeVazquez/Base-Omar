import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../widgets/custom_text_field.dart';
import '../models/empresa_entrenador.dart';

class AdminEmpresasScreen extends StatefulWidget {
  const AdminEmpresasScreen({super.key});

  @override
  State<AdminEmpresasScreen> createState() => _AdminEmpresasScreenState();
}

class _AdminEmpresasScreenState extends State<AdminEmpresasScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _tableMissing = false;
  List<EmpresaEntrenador> _empresas = [];

  @override
  void initState() {
    super.initState();
    _fetchEmpresas();
  }

  Future<void> _fetchEmpresas() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _tableMissing = false;
    });

    try {
      final response = await _supabase
          .from('EmpresasEntrenadores')
          .select()
          .order('nombre', ascending: true);

      setState(() {
        _empresas = (response as List)
            .map((json) => EmpresaEntrenador.fromJson(json))
            .toList();
      });
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('relation') && (errorStr.contains('does not exist') || errorStr.contains('no existe'))) {
        setState(() {
          _tableMissing = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar empresas: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEmpresa(EmpresaEntrenador empresa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Empresa/Entrenador'),
        content: Text('¿Estás seguro de que deseas eliminar a "${empresa.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('EmpresasEntrenadores')
          .delete()
          .eq('IDEmpresa', empresa.idEmpresa);

      _fetchEmpresas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Empresa eliminada exitosamente.', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showAddEditDialog([EmpresaEntrenador? empresa]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EmpresaFormDialog(
        empresa: empresa,
        onSaved: _fetchEmpresas,
      ),
    );
  }

  void _showReviewsDialog(EmpresaEntrenador empresa) {
    showDialog(
      context: context,
      builder: (context) => _EmpresaReviewsDialog(
        empresa: empresa,
        onReviewsUpdated: _fetchEmpresas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tableMissing) {
      return _buildTableMissingWidget();
    }

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : RefreshIndicator(
            onRefresh: _fetchEmpresas,
            color: Colors.black,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Empresas y Entrenadores',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditDialog(),
                        icon: const Icon(Icons.add, color: Colors.white, size: 18),
                        label: const Text('Nueva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_empresas.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No hay empresas o entrenadores registrados.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  else
                    ..._empresas.map((e) => _buildEmpresaCard(e)),
                ],
              ),
            ),
          );
  }

  Widget _buildTableMissingWidget() {
    const String sqlCode = '''CREATE TABLE IF NOT EXISTS "public"."EmpresasEntrenadores" (
    "IDEmpresa" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "created_at" timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    "nombre" text NOT NULL,
    "correo_electronico" text NOT NULL,
    "numero_clientes" integer DEFAULT 0 NOT NULL,
    "fecha_corte" date,
    "calificacion" double precision DEFAULT 0.0 NOT NULL,
    "reseñas" jsonb DEFAULT '[]'::jsonb NOT NULL
);''';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Tabla Faltante en Supabase',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 12),
              const Text(
                'La tabla "EmpresasEntrenadores" no existe en la base de datos de tu Supabase. Por favor ejecuta el siguiente script SQL en el Editor SQL de tu consola de Supabase y presiona Reintentar:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const SelectableText(
                  sqlCode,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchEmpresas,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Reintentar Cargar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpresaCard(EmpresaEntrenador empresa) {
    final dateFormat = intl.DateFormat('dd/MM/yyyy');
    final formattedDate = empresa.fechaCorte != null ? dateFormat.format(empresa.fechaCorte!) : 'No definida';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon / Avatar representation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fitness_center,
                size: 28,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    empresa.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    empresa.correoElectronico,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Mini KPIs
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildMiniBadge(
                        Icons.people,
                        '${empresa.numeroClientes} Clientes',
                        Colors.blue,
                      ),
                      _buildMiniBadge(
                        Icons.calendar_today,
                        'Corte: $formattedDate',
                        Colors.orange,
                      ),
                      _buildMiniBadge(
                        Icons.star,
                        '${empresa.calificacion.toStringAsFixed(1)} (${empresa.resenas.length} reseñas)',
                        Colors.amber[700]!,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.rate_review_outlined, color: Colors.blueAccent),
                  tooltip: 'Ver Reseñas',
                  onPressed: () => _showReviewsDialog(empresa),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.black87),
                  tooltip: 'Editar',
                  onPressed: () => _showAddEditDialog(empresa),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Eliminar',
                  onPressed: () => _deleteEmpresa(empresa),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmpresaFormDialog extends StatefulWidget {
  final EmpresaEntrenador? empresa;
  final VoidCallback onSaved;

  const _EmpresaFormDialog({this.empresa, required this.onSaved});

  @override
  State<_EmpresaFormDialog> createState() => _EmpresaFormDialogState();
}

class _EmpresaFormDialogState extends State<_EmpresaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _clientsController = TextEditingController();
  final _ratingController = TextEditingController();
  DateTime? _selectedCutoffDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.empresa != null) {
      _nameController.text = widget.empresa!.nombre;
      _emailController.text = widget.empresa!.correoElectronico;
      _clientsController.text = widget.empresa!.numeroClientes.toString();
      _ratingController.text = widget.empresa!.calificacion.toString();
      _selectedCutoffDate = widget.empresa!.fechaCorte;
    } else {
      _clientsController.text = '0';
      _ratingController.text = '0.0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _clientsController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedCutoffDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedCutoffDate) {
      setState(() {
        _selectedCutoffDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;

    final nombre = _nameController.text.trim();
    final email = _emailController.text.trim();
    final numClientes = int.tryParse(_clientsController.text) ?? 0;
    final rating = double.tryParse(_ratingController.text) ?? 0.0;
    final String? cutoffStr = _selectedCutoffDate != null
        ? "${_selectedCutoffDate!.year.toString().padLeft(4, '0')}-${_selectedCutoffDate!.month.toString().padLeft(2, '0')}-${_selectedCutoffDate!.day.toString().padLeft(2, '0')}"
        : null;

    final data = <String, dynamic>{
      'nombre': nombre,
      'correo_electronico': email,
      'numero_clientes': numClientes,
      'fecha_corte': cutoffStr,
      'calificacion': rating,
    };

    try {
      if (widget.empresa == null) {
        // Insert new
        data['reseñas'] = []; // default empty array
        await supabase.from('EmpresasEntrenadores').insert(data);
      } else {
        // Update existing
        await supabase
            .from('EmpresasEntrenadores')
            .update(data)
            .eq('IDEmpresa', widget.empresa!.idEmpresa);
      }

      widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar datos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.empresa == null;
    final dateFormat = intl.DateFormat('dd/MM/yyyy');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isNew ? 'Nueva Empresa / Entrenador' : 'Editar Empresa / Entrenador',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _nameController,
                labelText: 'Nombre Comercial / Entrenador',
                validator: (val) => val == null || val.trim().isEmpty ? 'Nombre requerido' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                labelText: 'Correo Electrónico',
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Correo requerido';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                    return 'Ingrese un correo electrónico válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _clientsController,
                labelText: 'Número de Clientes',
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _ratingController,
                labelText: 'Calificación (1.0 - 5.0)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Requerido';
                  final r = double.tryParse(val);
                  if (r == null || r < 0 || r > 5) return 'Calificación de 0 a 5';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCutoffDate == null
                            ? 'Seleccionar Fecha de Corte'
                            : 'Fecha Corte: ${dateFormat.format(_selectedCutoffDate!)}',
                        style: TextStyle(
                          color: _selectedCutoffDate == null ? Colors.black54 : Colors.black,
                        ),
                      ),
                      const Icon(Icons.calendar_month, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _EmpresaReviewsDialog extends StatefulWidget {
  final EmpresaEntrenador empresa;
  final VoidCallback onReviewsUpdated;

  const _EmpresaReviewsDialog({required this.empresa, required this.onReviewsUpdated});

  @override
  State<_EmpresaReviewsDialog> createState() => _EmpresaReviewsDialogState();
}

class _EmpresaReviewsDialogState extends State<_EmpresaReviewsDialog> {
  final _authorController = TextEditingController();
  final _commentController = TextEditingController();
  double _rating = 5.0;
  bool _isSaving = false;
  late List<dynamic> _localReviews;

  @override
  void initState() {
    super.initState();
    _localReviews = List.from(widget.empresa.resenas);
  }

  @override
  void dispose() {
    _authorController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addReview() async {
    final author = _authorController.text.trim();
    final comment = _commentController.text.trim();
    if (author.isEmpty || comment.isEmpty) return;

    setState(() => _isSaving = true);

    final newReview = {
      'autor': author,
      'comentario': comment,
      'calificacion': _rating,
      'fecha': DateTime.now().toIso8601String(),
    };

    final updatedReviews = [..._localReviews, newReview];

    // Calculate new average rating
    double sum = 0.0;
    for (var r in updatedReviews) {
      sum += double.tryParse(r['calificacion']?.toString() ?? '5.0') ?? 5.0;
    }
    final double newAvgRating = updatedReviews.isEmpty ? 0.0 : sum / updatedReviews.length;

    try {
      await Supabase.instance.client
          .from('EmpresasEntrenadores')
          .update({
            'reseñas': updatedReviews,
            'calificacion': double.parse(newAvgRating.toStringAsFixed(1)),
          })
          .eq('IDEmpresa', widget.empresa.idEmpresa);

      setState(() {
        _localReviews = updatedReviews;
        _authorController.clear();
        _commentController.clear();
        _rating = 5.0;
        _isSaving = false;
      });
      widget.onReviewsUpdated();
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar reseña: $e')),
      );
    }
  }

  Future<void> _deleteReview(int index) async {
    setState(() => _isSaving = true);
    final updatedReviews = List.from(_localReviews)..removeAt(index);

    // Calculate new average rating
    double sum = 0.0;
    for (var r in updatedReviews) {
      sum += double.tryParse(r['calificacion']?.toString() ?? '5.0') ?? 5.0;
    }
    final double newAvgRating = updatedReviews.isEmpty ? 0.0 : sum / updatedReviews.length;

    try {
      await Supabase.instance.client
          .from('EmpresasEntrenadores')
          .update({
            'reseñas': updatedReviews,
            'calificacion': double.parse(newAvgRating.toStringAsFixed(1)),
          })
          .eq('IDEmpresa', widget.empresa.idEmpresa);

      setState(() {
        _localReviews = updatedReviews;
        _isSaving = false;
      });
      widget.onReviewsUpdated();
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar reseña: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = intl.DateFormat('dd/MM/yyyy HH:mm');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Reseñas de ${widget.empresa.nombre}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _localReviews.isEmpty
                    ? const Center(child: Text('No hay reseñas registradas aún.', style: TextStyle(color: Colors.black54)))
                    : ListView.builder(
                        itemCount: _localReviews.length,
                        itemBuilder: (context, idx) {
                          final r = _localReviews[idx] as Map;
                          final dateStr = r['fecha']?.toString();
                          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
                          final formattedDate = date != null ? dateFormat.format(date.toLocal()) : '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Colors.grey[50],
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r['autor']?.toString() ?? 'Anónimo',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.star, size: 14, color: Colors.amber[700]),
                                          const SizedBox(width: 2),
                                          Text(
                                            r['calificacion']?.toString() ?? '5.0',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: _isSaving ? null : () => _deleteReview(idx),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r['comentario']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                  if (formattedDate.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      formattedDate,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              const Text('Añadir Nueva Reseña', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _authorController,
                      labelText: 'Nombre del Autor',
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<double>(
                    value: _rating,
                    items: [1.0, 2.0, 3.0, 4.0, 5.0].map((val) {
                      return DropdownMenuItem<double>(
                        value: val,
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text(val.toStringAsFixed(0)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _rating = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _commentController,
                labelText: 'Comentario / Reseña',
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isSaving ? null : _addReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Agregar Reseña', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
