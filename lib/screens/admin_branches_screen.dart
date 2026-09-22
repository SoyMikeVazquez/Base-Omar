import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_text_field.dart';

class AdminBranchesScreen extends StatefulWidget {
  const AdminBranchesScreen({super.key});

  @override
  State<AdminBranchesScreen> createState() => _AdminBranchesScreenState();
}

class _AdminBranchesScreenState extends State<AdminBranchesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Sucursales')
          .select()
          .eq('IDGeneral', 'FRFROIJNU821')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal Canarios')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal florida')
          .order('NombreSucursal', ascending: true);
      setState(() {
        _branches = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar sucursales: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBranch(String idSucursal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Sucursal'),
        content: const Text('¿Estás seguro de que deseas eliminar esta sucursal? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.black))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('Sucursales').delete().eq('IDSucursal', idSucursal);
      _fetchBranches();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucursal eliminada extiosametne.', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  void _showAddEditBranchDialog([Map<String, dynamic>? branch]) {
    showDialog(
      context: context,
      builder: (context) => _BranchFormDialog(
        branch: branch,
        onSaved: _fetchBranches,
      ),
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
                    const Text('Administrar Sucursales', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditBranchDialog(),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Nueva', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_branches.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay sucursales registradas.')))
                else
                  ..._branches.map((b) => _buildBranchCard(b)),
              ],
            ),
          );
  }

  Widget _buildBranchCard(Map<String, dynamic> branch) {
    final photo = branch['FotoSucucrsal'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null && photo.toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                photo,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.storefront, size: 50, color: Colors.black26),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch['NombreSucursal'] ?? 'Sin Nombre', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(branch['Ubicación'] ?? '', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                            child: Text(branch['pricePremium'] == true ? 'Premium' : 'Estándar', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          if (branch['Submarca'] != null)
                             Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                              child: Text(branch['Submarca'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.black),
                      onPressed: () => _showAddEditBranchDialog(branch),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteBranch(branch['IDSucursal']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchFormDialog extends StatefulWidget {
  final Map<String, dynamic>? branch;
  final VoidCallback onSaved;

  const _BranchFormDialog({this.branch, required this.onSaved});

  @override
  State<_BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<_BranchFormDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _linkController = TextEditingController();
  final _subbrandController = TextEditingController();
  int _priceLevel = 1;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _currentPhotoUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.branch != null) {
      _nameController.text = widget.branch!['NombreSucursal'] ?? '';
      _addressController.text = widget.branch!['Ubicación'] ?? '';
      _linkController.text = widget.branch!['UbicaciónLink'] ?? '';
      _subbrandController.text = widget.branch!['Submarca'] ?? '';
      _priceLevel = widget.branch!['NivelDePrecio'] ?? 1;
      _currentPhotoUrl = widget.branch!['FotoSucucrsal'];
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageFile  = pickedFile;
        _imageBytes = bytes;
      });
    }
  }

  Widget _photoPlaceholder() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 40, color: Colors.black38),
          SizedBox(height: 8),
          Text('Sin foto', style: TextStyle(color: Colors.black38)),
        ],
      );

  Future<void> _saveBranch() async {
    if (_nameController.text.trim().isEmpty) return;
    
    setState(() => _isUploading = true);

    try {
      String? photoUrl = _currentPhotoUrl;

      // Upload image if a new one was picked
      if (_imageFile != null && _imageBytes != null) {
        final fileExt = _imageFile!.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'locations/$fileName';

        await Supabase.instance.client.storage
            .from('sucursales')
            .uploadBinary(
              filePath, 
              _imageBytes!,
              fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
            );

        photoUrl = Supabase.instance.client.storage
            .from('sucursales')
            .getPublicUrl(filePath);
      }

      final data = <String, dynamic>{
        'NombreSucursal': _nameController.text.trim(),
        'Ubicación': _addressController.text.trim(),
        'UbicaciónLink': _linkController.text.trim(),
        'Submarca': _subbrandController.text.trim(),
        'NivelDePrecio': _priceLevel,
        'pricePremium': _priceLevel == 3, // auto-set based on level
        'IDGeneral': 'FRFROIJNU821',
        if (photoUrl != null) 'FotoSucucrsal': photoUrl,
      };

      if (widget.branch == null) {
        // Create new
        final sucursalId = DateTime.now().millisecondsSinceEpoch.toString();
        data['IDSucursal'] = sucursalId;
        data['IDSucursales'] = sucursalId;
        await Supabase.instance.client.from('Sucursales').insert(data);
      } else {
        // Update
        await Supabase.instance.client.from('Sucursales').update(data).eq('IDSucursal', widget.branch!['IDSucursal']);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.branch == null ? 'Nueva Sucursal' : 'Editar Sucursal',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Image preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                          ? Image.network(_currentPhotoUrl!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _photoPlaceholder())
                          : _photoPlaceholder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo, size: 18),
                  label: Text(_imageBytes != null || (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                      ? 'Cambiar foto'
                      : 'Subir foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black26),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CustomTextField(controller: _nameController, label: 'Nombre de la Sucursal', prefixIcon: Icons.storefront),
              const SizedBox(height: 12),
              CustomTextField(controller: _addressController, label: 'Ubicación / Dirección', prefixIcon: Icons.location_on_outlined),
              const SizedBox(height: 12),
              CustomTextField(controller: _linkController, label: 'Link de Google Maps', prefixIcon: Icons.map_outlined),
              const SizedBox(height: 12),
              CustomTextField(controller: _subbrandController, label: 'Submarca (opcional)', prefixIcon: Icons.branding_watermark_outlined),
              const SizedBox(height: 20),
              // ── Price tier selector ──────────────────────────────────
              const Text('Nivel de Precio del Servicio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'Determina qué columna de precio se usará al agendar en esta sucursal.',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _PriceTierBtn(label: 'Estándar', level: 1, selected: _priceLevel == 1, onTap: () => setState(() => _priceLevel = 1)),
                  const SizedBox(width: 8),
                  _PriceTierBtn(label: 'Elevado',  level: 2, selected: _priceLevel == 2, onTap: () => setState(() => _priceLevel = 2)),
                  const SizedBox(width: 8),
                  _PriceTierBtn(label: 'Premium ✦', level: 3, selected: _priceLevel == 3, onTap: () => setState(() => _priceLevel = 3)),
                ],
              ),
              const SizedBox(height: 24),
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
                      onPressed: _isUploading ? null : _saveBranch,
                      child: _isUploading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceTierBtn extends StatelessWidget {
  final String label;
  final int level;
  final bool selected;
  final VoidCallback onTap;
  const _PriceTierBtn({required this.label, required this.level, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.black : Colors.black12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
