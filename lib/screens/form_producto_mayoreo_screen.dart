import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FormProductoMayoreoScreen extends StatefulWidget {
  final Map<String, dynamic>? producto;

  const FormProductoMayoreoScreen({super.key, this.producto});

  @override
  State<FormProductoMayoreoScreen> createState() => _FormProductoMayoreoScreenState();
}

class _FormProductoMayoreoScreenState extends State<FormProductoMayoreoScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _precioBaseCtrl = TextEditingController();
  final TextEditingController _miniDescCtrl = TextEditingController();

  List<Map<String, dynamic>> _descuentos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.producto != null) {
      _nombreCtrl.text = widget.producto!['nombre'] ?? '';
      _precioBaseCtrl.text = widget.producto!['precio_base']?.toString() ?? '';
      _miniDescCtrl.text = widget.producto!['mini_descripcion'] ?? '';
      
      if (widget.producto!['descuentos_por_volumen'] != null) {
        final List<dynamic> desc = widget.producto!['descuentos_por_volumen'];
        _descuentos = desc.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
  }

  void _addDescuento() {
    setState(() {
      _descuentos.add({
        'cantidad': null,
        'porcentaje': null,
      });
    });
  }

  void _removeDescuento(int index) {
    setState(() {
      _descuentos.removeAt(index);
    });
  }

  Future<void> _saveProducto() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate descuentos
    for (var i = 0; i < _descuentos.length; i++) {
      if (_descuentos[i]['cantidad'] == null || _descuentos[i]['porcentaje'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor llena todos los campos de descuento.')));
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final data = {
        'nombre': _nombreCtrl.text,
        'precio_base': double.tryParse(_precioBaseCtrl.text) ?? 0,
        'mini_descripcion': _miniDescCtrl.text,
        'descuentos_por_volumen': _descuentos,
      };

      if (widget.producto == null) {
        // Insert
        await _supabase.from('productos_mayoreo').insert(data);
      } else {
        // Update
        await _supabase.from('productos_mayoreo').update(data).eq('id', widget.producto!['id']);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.producto != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Información Básica', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Producto', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _precioBaseCtrl,
                decoration: const InputDecoration(labelText: 'Precio Base (\$)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _miniDescCtrl,
                decoration: const InputDecoration(labelText: 'Mini Descripción (Opcional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Descuentos por Volumen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addDescuento,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  )
                ],
              ),
              const SizedBox(height: 10),
              
              if (_descuentos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No hay niveles de descuento configurados. Se cobrará precio base siempre.', style: TextStyle(color: Colors.grey)),
                ),

              ..._descuentos.asMap().entries.map((entry) {
                int idx = entry.key;
                Map<String, dynamic> descuento = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: descuento['cantidad']?.toString() ?? '',
                            decoration: const InputDecoration(labelText: 'Cantidad Mínima', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _descuentos[idx]['cantidad'] = int.tryParse(val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: descuento['porcentaje']?.toString() ?? '',
                            decoration: const InputDecoration(labelText: '% de Descuento', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => _descuentos[idx]['porcentaje'] = double.tryParse(val),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeDescuento(idx),
                        )
                      ],
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProducto,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Producto', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
