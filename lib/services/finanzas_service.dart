import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinanzasService {
  final _supabase = Supabase.instance.client;

  Future<void> insertarRegistro({
    required String personalId,
    required List<String> serviciosIds,
    required List<Map<String, dynamic>> serviciosDetalle,
    required double sumaServicios,
    required double montosExtras,
    String? descripcionExtras,
    String? formaPago,
    DateTime? fecha,
    String? sucursal,
    String? sucursalId,
    String? gasto,
    String? quienRegistro,
    String? clienteId,
    String? clienteEmail,
    String? clienteTelefono,
    String? clienteNombre,
    String? tipoTransaccion,
  }) async {
    String? resolvedSucursalId = sucursalId;
    if (resolvedSucursalId == null && sucursal != null && sucursal.isNotEmpty) {
      try {
        final res = await _supabase
            .from('Sucursales')
            .select('IDSucursal')
            .eq('NombreSucursal', sucursal)
            .maybeSingle();
        if (res != null) {
          resolvedSucursalId = res['IDSucursal']?.toString();
        }
      } catch (e) {
        debugPrint('Error obtaining sucursalId: $e');
      }
    }

    final total = (sumaServicios + montosExtras);
    final data = {
      'personalID': personalId,
      'servicios_ids': serviciosIds,
      'servicios_detalle': serviciosDetalle,
      'suma_servicios': sumaServicios,
      'montos_extras': montosExtras,
      'descripcion_extras': descripcionExtras,
      'formadepago': formaPago,
      if (fecha != null) 'fecha': fecha.toIso8601String(),
      if (sucursal != null) 'sucursal': sucursal,
      if (resolvedSucursalId != null) 'sucursal_id': resolvedSucursalId,
      'total': total,
      if (gasto != null) 'Gasto': gasto,
      if (quienRegistro != null) 'QuienRegistro': quienRegistro,
      if (clienteId != null) 'cliente_id': clienteId,
      if (clienteEmail != null) 'cliente_email': clienteEmail,
      if (clienteTelefono != null) 'cliente_telefono': clienteTelefono,
      if (clienteNombre != null) 'cliente_nombre': clienteNombre,
      if (tipoTransaccion != null) 'tipodetransacción': tipoTransaccion,
    };

    await _supabase.from('FinanzasPersonal').insert(data);
  }

  Future<List<Map<String, dynamic>>> fetchProductos() async {
    try {
      final response = await _supabase.from('Productos').select().order('NombreProducto');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> insertarOrdenProductos({
    required String personalId,
    required List<Map<String, dynamic>> productosDetalle,
    required double sumaProductos,
    String? formaPago,
    DateTime? fecha,
    String? sucursal,
    String? sucursalId,
    String? quienRegistro,
    String? clienteId,
    String? clienteEmail,
    String? clienteTelefono,
    String? clienteNombre,
  }) async {
    String? resolvedSucursalId = sucursalId;
    if (resolvedSucursalId == null && sucursal != null && sucursal.isNotEmpty) {
      try {
        final res = await _supabase
            .from('Sucursales')
            .select('IDSucursal')
            .eq('NombreSucursal', sucursal)
            .maybeSingle();
        if (res != null) {
          resolvedSucursalId = res['IDSucursal']?.toString();
        }
      } catch (e) {
        debugPrint('Error obtaining sucursalId: $e');
      }
    }

    final data = {
      'personal_id': personalId,
      'productos_detalle': productosDetalle,
      'suma_productos': sumaProductos,
      'formadepago': formaPago ?? 'En efectivo',
      if (fecha != null) 'fecha': fecha.toIso8601String(),
      if (sucursal != null) 'sucursal': sucursal,
      if (resolvedSucursalId != null) 'sucursal_id': resolvedSucursalId,
      'QuienRegistro': quienRegistro ?? 'recepcion',
      if (clienteId != null) 'cliente_id': clienteId,
      if (clienteEmail != null) 'cliente_email': clienteEmail,
      if (clienteTelefono != null) 'cliente_telefono': clienteTelefono,
      if (clienteNombre != null) 'cliente_nombre': clienteNombre,
    };

    // Insertar la orden
    await _supabase.from('OrdenesProductos').insert(data);

    // Actualizar el stock de cada producto vendido
    for (var prod in productosDetalle) {
      final productoId = prod['id'];
      final cantidad = prod['cantidad'] as int;

      try {
        final currentProdResp = await _supabase
            .from('Productos')
            .select('stock')
            .eq('id', productoId)
            .single();
        final currentStock = currentProdResp['stock'] as int;
        await _supabase
            .from('Productos')
            .update({'stock': currentStock - cantidad})
            .eq('id', productoId);
      } catch (e) {
        // Log error o manejar si el producto no se encuentra
      }
    }
  }
}
