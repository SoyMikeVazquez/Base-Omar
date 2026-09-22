import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/email_service.dart';
import 'productos_mayoreo_screen.dart';
import 'notas_history_screen.dart';

class NoteItem {
  final String id = UniqueKey().toString();
  String nombre;
  int cantidad;
  double precioBase;
  bool esPersonalizado;
  List<dynamic> descuentosPorVolumen;
  double? precioOverride;

  NoteItem({
    required this.nombre,
    this.cantidad = 1,
    required this.precioBase,
    this.esPersonalizado = false,
    this.descuentosPorVolumen = const [],
    this.precioOverride,
  });

  double get precioUnitario {
    if (precioOverride != null) return precioOverride!;

    if (esPersonalizado || descuentosPorVolumen.isEmpty) {
      return precioBase;
    }
    
    final sortedDescuentos = List<Map<String, dynamic>>.from(descuentosPorVolumen)
      ..sort((a, b) => (b['cantidad'] as num).compareTo(a['cantidad'] as num));

    for (final desc in sortedDescuentos) {
      final int minQty = (desc['cantidad'] as num).toInt();
      final double porcentaje = (desc['porcentaje'] as num).toDouble();
      if (cantidad >= minQty) {
        return precioBase * (1.0 - (porcentaje / 100.0));
      }
    }

    return precioBase;
  }

  double get total => cantidad * precioUnitario;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'cantidad': cantidad,
    'precio_base': precioBase,
    'precio_unitario': precioUnitario,
    'total': total,
    'es_personalizado': esPersonalizado,
  };
}

class CreateNoteScreen extends StatefulWidget {
  final Map<String, dynamic>? notaToEdit;
  const CreateNoteScreen({super.key, this.notaToEdit});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool get isEditing => widget.notaToEdit != null;

  // Customer Data
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _descuentoEspecialCtrl = TextEditingController(text: '0');
  final TextEditingController _envioCtrl = TextEditingController(text: '0');
  final TextEditingController _anticipoCtrl = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();

  List<dynamic> _availableCatalog = [];
  List<NoteItem> _selectedItems = [];
  bool _isLoadingCatalog = false;
  bool _isGenerating = false;

  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void dispose() {
    for (var c in _qtyControllers.values) {
      c.dispose();
    }
    for (var c in _priceControllers.values) {
      c.dispose();
    }
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _descuentoEspecialCtrl.dispose();
    _envioCtrl.dispose();
    _anticipoCtrl.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    return price == price.toInt() ? price.toInt().toString() : price.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final nota = widget.notaToEdit!;
      _nameCtrl.text = nota['cliente_nombre'] ?? '';
      _addressCtrl.text = nota['cliente_direccion'] ?? '';
      _phoneCtrl.text = nota['cliente_telefono'] ?? '';
      _emailCtrl.text = nota['cliente_correo'] ?? '';
      _descuentoEspecialCtrl.text = _formatPrice((nota['descuento_especial'] as num?)?.toDouble() ?? 0.0);
      _envioCtrl.text = _formatPrice((nota['envio'] as num?)?.toDouble() ?? 0.0);
      _anticipoCtrl.text = _formatPrice((nota['anticipo'] as num?)?.toDouble() ?? 0.0);
      _applyIVA = nota['aplica_iva'] == true;

      if (nota['created_at'] != null) {
        _selectedDate = DateTime.tryParse(nota['created_at']) ?? DateTime.now();
      }

      final rawItems = nota['items'] as List<dynamic>? ?? [];
      for (var r in rawItems) {
        final double? pUnit = (r['precio_unitario'] as num?)?.toDouble();
        final double? pBase = (r['precio_base'] as num?)?.toDouble();
        final bool esCustom = r['es_personalizado'] == true;
        final int qty = (r['cantidad'] as num?)?.toInt() ?? 1;

        final item = NoteItem(
          nombre: r['nombre'] ?? '',
          cantidad: qty,
          precioBase: pBase ?? pUnit ?? 0.0,
          esPersonalizado: esCustom,
          precioOverride: (!esCustom && pBase != null && pUnit != null && pBase != pUnit)
              ? pUnit
              : (esCustom ? null : pUnit),
        );
        _qtyControllers[item.id] = TextEditingController(text: item.cantidad.toString());
        _priceControllers[item.id] = TextEditingController(text: _formatPrice(item.precioUnitario));
        _selectedItems.add(item);
      }
    }
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoadingCatalog = true);
    try {
      final res = await _supabase.from('productos_mayoreo').select().order('nombre');
      setState(() {
        _availableCatalog = res;
        if (isEditing) {
          for (var item in _selectedItems) {
            if (!item.esPersonalizado) {
              final match = _availableCatalog.firstWhere(
                (p) => p['nombre'] == item.nombre,
                orElse: () => null,
              );
              if (match != null) {
                item.descuentosPorVolumen = match['descuentos_por_volumen'] ?? [];
              }
            }
          }
        }
      });
    } catch (e) {
      // Fail silently
    } finally {
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  void _addWholesaleProduct(Map<String, dynamic> prod) {
    setState(() {
      final item = NoteItem(
        nombre: prod['nombre'],
        precioBase: (prod['precio_base'] as num).toDouble(),
        descuentosPorVolumen: prod['descuentos_por_volumen'] ?? [],
        cantidad: 30, 
      );
      _qtyControllers[item.id] = TextEditingController(text: item.cantidad.toString());
      _priceControllers[item.id] = TextEditingController(text: _formatPrice(item.precioUnitario));
      _selectedItems.add(item);
    });
  }

  void _addCustomRow() {
    setState(() {
      final item = NoteItem(
        nombre: 'Concepto Personalizado',
        precioBase: 100.0,
        cantidad: 1,
        esPersonalizado: true,
      );
      _qtyControllers[item.id] = TextEditingController(text: item.cantidad.toString());
      _priceControllers[item.id] = TextEditingController(text: _formatPrice(item.precioUnitario));
      _selectedItems.add(item);
    });
  }

  bool _applyIVA = false;

  double get _subtotal {
    return _selectedItems.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _descuentoEspecial {
    return double.tryParse(_descuentoEspecialCtrl.text) ?? 0.0;
  }

  double get _iva {
    if (!_applyIVA) return 0.0;
    final t = _subtotal - _descuentoEspecial;
    return (t < 0 ? 0.0 : t) * 0.16;
  }

  double get _envio => double.tryParse(_envioCtrl.text) ?? 0.0;
  double get _anticipo => double.tryParse(_anticipoCtrl.text) ?? 0.0;

  double get _grandTotal {
    final t = _subtotal - _descuentoEspecial;
    final base = t < 0 ? 0.0 : t;
    return base + _iva + _envio;
  }

  double get _restante {
    final res = _grandTotal - _anticipo;
    return res < 0 ? 0.0 : res;
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _selectedDate.hour,
            _selectedDate.minute,
          );
        });
      }
    }
  }

  Future<void> _generateAndSavePdf() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor agrega al menos un producto a la nota.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 1. Save or update note in Supabase
      final rawItems = _selectedItems.map((e) => e.toJson()).toList();

      int folio;
      final bool isRecibo = widget.notaToEdit?['es_recibo'] == true;
      final String tituloDocumento = isRecibo ? 'RECIBO DE CUENTA' : 'PRESUPUESTO';
      
      final String dateSuffix = DateFormat('ddMMyy').format(_selectedDate);

      if (isEditing) {
        folio = widget.notaToEdit!['folio'] ?? 1;
        final noteData = {
          'cliente_nombre': _nameCtrl.text,
          'cliente_direccion': _addressCtrl.text,
          'cliente_telefono': _phoneCtrl.text,
          'cliente_correo': _emailCtrl.text,
          'items': rawItems,
          'descuento_especial': _descuentoEspecial,
          'subtotal': _subtotal,
          'total': _grandTotal,
          'aplica_iva': _applyIVA,
          'iva': _iva,
          'envio': _envio,
          'anticipo': _anticipo,
          'created_at': _selectedDate.toIso8601String(),
        };
        await _supabase.from('notas_venta').update(noteData).eq('id', widget.notaToEdit!['id']);
      } else {
        final noteData = {
          'cliente_nombre': _nameCtrl.text,
          'cliente_direccion': _addressCtrl.text,
          'cliente_telefono': _phoneCtrl.text,
          'cliente_correo': _emailCtrl.text,
          'items': rawItems,
          'descuento_especial': _descuentoEspecial,
          'subtotal': _subtotal,
          'total': _grandTotal,
          'aplica_iva': _applyIVA,
          'iva': _iva,
          'envio': _envio,
          'anticipo': _anticipo,
          'finalizada': true,
          'created_at': _selectedDate.toIso8601String(),
        };
        final insertedNote = await _supabase.from('notas_venta').insert(noteData).select().single();
        folio = insertedNote['folio'] ?? 1;
      }
      
      final String folioStr = '${folio.toString().padLeft(4, '0')}-$dateSuffix';

      // 2. Generate PDF with 7 items per page
      final PdfDocument document = PdfDocument();

      final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
      final PdfFont subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
      final PdfFont regularFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
      final PdfFont sectionHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
      final PdfFont totalsFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);

      // Large Banking Fonts (Double size!)
      final PdfFont bankHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
      final PdfFont bankBodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
      final PdfFont condFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5);

      const int itemsPerPage = 7;
      final int totalPages = (rawItems.isEmpty) ? 1 : (rawItems.length / itemsPerPage).ceil();

      Uint8List? topLogoBytes;
      try {
        final ByteData b = await rootBundle.load('assets/logosuperior.png');
        topLogoBytes = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
      } catch (e) {
        debugPrint('Error cargando logosuperior.png: $e');
        try {
          final ByteData b = await rootBundle.load('assets/logo.png');
          topLogoBytes = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
        } catch (_) {}
      }

      Uint8List? watermarkBytes;
      try {
        final ByteData b = await rootBundle.load('assets/marcadeagua.png');
        watermarkBytes = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
      } catch (e) {
        debugPrint('Error cargando marcadeagua.png: $e');
      }

      for (int p = 0; p < totalPages; p++) {
        final PdfPage page = document.pages.add();
        final Size clientSize = page.getClientSize();

        // 1. Draw Watermark in Background
        if (watermarkBytes != null) {
          final PdfBitmap watermarkImage = PdfBitmap(watermarkBytes);
          page.graphics.save();
          page.graphics.setTransparency(0.12); // subtle opacity
          final double aspect = watermarkImage.width / watermarkImage.height;
          const double maxWmW = 340.0;
          const double maxWmH = 340.0;
          double wmW = maxWmW;
          double wmH = wmW / aspect;
          if (wmH > maxWmH) {
            wmH = maxWmH;
            wmW = wmH * aspect;
          }
          page.graphics.drawImage(
            watermarkImage,
            Rect.fromLTWH((clientSize.width - wmW) / 2, (clientSize.height - wmH) / 2, wmW, wmH),
          );
          page.graphics.restore();
        }

        // 2. Draw Top Left Logo
        if (topLogoBytes != null) {
          final PdfBitmap logoImage = PdfBitmap(topLogoBytes);
          final double aspect = logoImage.width / logoImage.height;
          const double maxW = 90.0;
          const double maxH = 72.0;
          double drawW = maxW;
          double drawH = drawW / aspect;
          if (drawH > maxH) {
            drawH = maxH;
            drawW = drawH * aspect;
          }
          page.graphics.drawImage(logoImage, Rect.fromLTWH(0, 0, drawW, drawH));
        }

        // Header Text
        page.graphics.drawString('MAQUILA DE PRODUCTOS', titleFont, bounds: Rect.fromLTWH(80, 0, clientSize.width - 80, 22), format: PdfStringFormat(alignment: PdfTextAlignment.center));
        page.graphics.drawString(tituloDocumento, subtitleFont, bounds: Rect.fromLTWH(80, 22, clientSize.width - 80, 18), format: PdfStringFormat(alignment: PdfTextAlignment.center));

        page.graphics.drawString('Folio: #$folioStr', subtitleFont, bounds: Rect.fromLTWH(0, 45, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));

        final String dayStr = _selectedDate.day.toString().padLeft(2, '0');
        final String monthStr = _selectedDate.month.toString().padLeft(2, '0');
        final String formattedDate = '$dayStr/$monthStr/${_selectedDate.year} ${DateFormat('hh:mm a').format(_selectedDate)}';
        page.graphics.drawString('Fecha: $formattedDate', boldFont, bounds: Rect.fromLTWH(0, 65, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));

        if (totalPages > 1) {
          page.graphics.drawString('Página ${p + 1} de $totalPages', regularFont, bounds: Rect.fromLTWH(0, 80, clientSize.width, 15), format: PdfStringFormat(alignment: PdfTextAlignment.right));
        }

        // Customer Data
        double yOffset = 98;
        
        if (_applyIVA) {
          page.graphics.drawString('DATOS FISCALES DEL EMISOR', sectionHeaderFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 18));
          yOffset += 18;
          page.graphics.drawString('NOMBRE: MARTIN OMAR CHAVEZ PEREZ', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
          yOffset += 16;
          page.graphics.drawString('RFC: CAPM880922I36  |  CURP: CAPM880922HTSHRR04', regularFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
          yOffset += 16;
          page.graphics.drawString('RÉGIMEN SIMPLIFICADO DE CONFIANZA  |  C.P. 89606', regularFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
          yOffset += 24;
        }

        page.graphics.drawString('DATOS DEL CLIENTE', sectionHeaderFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 18));
        yOffset += 18;
        page.graphics.drawString('NOMBRE: ${_nameCtrl.text.toUpperCase()}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
        yOffset += 16;
        page.graphics.drawString('DIRECCIÓN: ${_addressCtrl.text.toUpperCase()}', regularFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
        yOffset += 16;
        page.graphics.drawString('TELÉFONO: ${_phoneCtrl.text}', regularFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
        yOffset += 16;
        if (_emailCtrl.text.isNotEmpty) {
          page.graphics.drawString('CORREO: ${_emailCtrl.text}', regularFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
          yOffset += 16;
        }

        yOffset += 10;

        // Items chunk for this page
        final int startIndex = p * itemsPerPage;
        final int endIndex = (startIndex + itemsPerPage < rawItems.length) ? startIndex + itemsPerPage : rawItems.length;
        final pageItems = rawItems.sublist(startIndex, endIndex);

        // Create Grid
        final PdfGrid grid = PdfGrid();
        grid.columns.add(count: 4);
        grid.headers.add(1);
        final PdfGridRow header = grid.headers[0];
        header.cells[0].value = 'CANT.';
        header.cells[1].value = 'DESCRIPCIÓN';
        header.cells[2].value = 'PRECIO UNITARIO';
        header.cells[3].value = 'TOTAL';

        final PdfGridCellStyle headerStyle = PdfGridCellStyle(
          font: PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
          backgroundBrush: PdfSolidBrush(PdfColor(30, 30, 30)),
          textBrush: PdfBrushes.white,
        );
        for (int i = 0; i < header.cells.count; i++) {
          header.cells[i].style = headerStyle;
          header.cells[i].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle);
        }

        final PdfGridCellStyle cellStyle = PdfGridCellStyle(
          font: PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold),
          cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4),
        );

        for (var item in pageItems) {
          final PdfGridRow row = grid.rows.add();
          final int qty = (item['cantidad'] as num).toInt();
          final String nombre = (item['nombre'] ?? '').toString();
          final double priceUnit = (item['precio_unitario'] as num).toDouble();
          final double itemTotal = (item['total'] as num).toDouble();

          row.cells[0].value = qty > 0 ? qty.toString() : '';
          row.cells[1].value = nombre.toUpperCase();
          row.cells[2].value = '\$${priceUnit.toStringAsFixed(2)}';
          row.cells[3].value = '\$${itemTotal.toStringAsFixed(2)}';

          for (int i = 0; i < row.cells.count; i++) {
            row.cells[i].style = cellStyle;
            row.cells[i].stringFormat = PdfStringFormat(alignment: i == 1 ? PdfTextAlignment.left : PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle);
          }
        }

        grid.columns[0].width = 55;
        grid.columns[2].width = 115;
        grid.columns[3].width = 100;

        final PdfLayoutResult result = grid.draw(
          page: page,
          bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 0),
        )!;

        yOffset = result.bounds.bottom + 12;

        if (p == totalPages - 1) {
          // Draw Totals on last page
          page.graphics.drawString('Subtotal: \$${_subtotal.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
          yOffset += 16;
          if (_descuentoEspecial > 0) {
            page.graphics.drawString('Descuento Especial: -\$${_descuentoEspecial.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
            yOffset += 16;
          }
          if (_applyIVA) {
            page.graphics.drawString('IVA (16%): \$${_iva.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
            yOffset += 16;
          }
          if (_envio > 0) {
            page.graphics.drawString('Envío: \$${_envio.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
            yOffset += 16;
          }
          page.graphics.drawString('TOTAL GENERAL: \$${_grandTotal.toStringAsFixed(2)}', totalsFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));
          yOffset += 18;
          if (_anticipo > 0) {
            page.graphics.drawString('Anticipo: \$${_anticipo.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
            yOffset += 16;
            page.graphics.drawString('RESTANTE PENDIENTE: \$${_restante.toStringAsFixed(2)}', totalsFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));
          }
        } else {
          page.graphics.drawString('(Continúa en la siguiente página...)', regularFont, bounds: Rect.fromLTWH(0, clientSize.height - 150, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
        }

        // 3. Footer on EVERY PAGE: DATOS BANCARIOS (Double Font Size) & CONDICIONES
        double footerY = clientSize.height - 135;

        page.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(30, 30, 30)),
          bounds: Rect.fromLTWH(0, footerY, clientSize.width, 22),
        );
        page.graphics.drawString(
          'DATOS BANCARIOS',
          bankHeaderFont,
          bounds: Rect.fromLTWH(0, footerY + 2, clientSize.width, 22),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        // White text for Header
        page.graphics.drawString(
          'DATOS BANCARIOS',
          PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold),
          bounds: Rect.fromLTWH(0, footerY + 3, clientSize.width, 22),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
          brush: PdfBrushes.white,
        );

        footerY += 26;
        final String bankDetailsLine1 = 'NOMBRE: OMAR CHAVEZ   |   BANCO: BBVA   |   TEL: 833 453 9727';
        final String bankDetailsLine2 = 'CLABE: 012 180 01536760721 4   |   TARJETA: 4152 3144 0280 6635';

        page.graphics.drawString(
          bankDetailsLine1,
          bankBodyFont,
          bounds: Rect.fromLTWH(0, footerY, clientSize.width, 16),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        footerY += 16;
        page.graphics.drawString(
          bankDetailsLine2,
          bankBodyFont,
          bounds: Rect.fromLTWH(0, footerY, clientSize.width, 16),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );

        footerY += 20;
        final String conditions = '''CONDICIONES DE PRODUCCIÓN
UNA VEZ CONFIRMADO EL PAGO, EL PEDIDO ENTRARÁ A PROCESO DE MAQUILA. EL TIEMPO ESTIMADO DE PRODUCCIÓN ES DE 8 DÍAS HÁBILES. EL TIEMPO DE ENVÍO NO ESTÁ INCLUIDO EN ESTE PLAZO. AL SER UN PRODUCTO PERSONALIZADO/MAQUILADO, NO SE ACEPTAN CAMBIOS NI DEVOLUCIONES UNA VEZ INICIADO EL PROCESO.''';

        page.graphics.drawString(
          conditions,
          condFont,
          bounds: Rect.fromLTWH(0, footerY, clientSize.width, 35),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      }

      // Save PDF bytes
      final List<int> savedBytes = document.saveSync();
      document.dispose();

      final Uint8List pdfBytes = Uint8List.fromList(savedBytes);

      // Send email via Resend if email is provided
      if (_emailCtrl.text.trim().isNotEmpty) {
        EmailService.sendNotaVentaEmail(
          toEmail: _emailCtrl.text.trim(),
          folioStr: folioStr,
          clientName: _nameCtrl.text.trim(),
          total: _grandTotal,
          items: rawItems,
          pdfBytes: pdfBytes,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Nota #$folioStr actualizada exitosamente.' : 'Nota #$folioStr guardada exitosamente.')),
        );

        if (isEditing) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const NotasHistoryScreen()),
            );
          }
        } else {
          // Navigate to NotasHistoryScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NotasHistoryScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Nota #${widget.notaToEdit!['folio'] ?? ''}' : 'Crear Nota de Venta',
          style: const TextStyle(color: Colors.black),
        ),
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
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProductosMayoreoScreen()),
                  );
                  _loadCatalog();
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Gestionar Catálogo de Mayoreo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Date picker selector
              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: const Text('Fecha y Hora de la Nota', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(DateFormat('dd/MM/yyyy hh:mm a').format(_selectedDate)),
                  trailing: TextButton(
                    onPressed: _selectDate,
                    child: const Text('Cambiar'),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              const Text('Datos del Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Cliente', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo Electrónico (Opcional)', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Productos & Conceptos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  PopupMenuButton<Map<String, dynamic>>(
                    tooltip: 'Agregar Producto',
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 28),
                    onSelected: _addWholesaleProduct,
                    itemBuilder: (context) {
                      return _availableCatalog.map((prod) {
                        return PopupMenuItem<Map<String, dynamic>>(
                          value: prod,
                          child: Text(prod['nombre']),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_selectedItems.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No has agregado productos a esta nota.', textAlign: TextAlign.center),
                  ),
                ),

              ..._selectedItems.asMap().entries.map((entry) {
                final int idx = entry.key;
                final NoteItem item = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: item.esPersonalizado
                                  ? TextFormField(
                                      initialValue: item.nombre,
                                      decoration: const InputDecoration(labelText: 'Nombre del Concepto'),
                                      onChanged: (val) => setState(() => item.nombre = val),
                                    )
                                  : Text(
                                      item.nombre,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _qtyControllers[item.id]?.dispose();
                                  _priceControllers[item.id]?.dispose();
                                  _qtyControllers.remove(item.id);
                                  _priceControllers.remove(item.id);
                                  _selectedItems.removeAt(idx);
                                });
                              },
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtyControllers[item.id],
                                decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  setState(() {
                                    item.cantidad = int.tryParse(val) ?? 0;
                                    if (!item.esPersonalizado && item.precioOverride == null) {
                                      final newPriceStr = _formatPrice(item.precioUnitario);
                                      if (_priceControllers[item.id]?.text != newPriceStr) {
                                        _priceControllers[item.id]?.text = newPriceStr;
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _priceControllers[item.id],
                                decoration: InputDecoration(
                                  labelText: 'Precio Unitario (\$)', 
                                  border: const OutlineInputBorder(),
                                  helperText: (!item.esPersonalizado && item.precioOverride == null && item.precioUnitario < item.precioBase)
                                      ? 'Sugerido base: \$${_formatPrice(item.precioBase)}'
                                      : null,
                                  helperStyle: const TextStyle(color: Colors.green, fontSize: 10),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (val) {
                                  final newPrice = double.tryParse(val);
                                  setState(() {
                                    if (newPrice != null) {
                                      if (item.esPersonalizado) {
                                        item.precioBase = newPrice;
                                      } else {
                                        item.precioOverride = newPrice;
                                      }
                                    } else if (val.isEmpty && !item.esPersonalizado) {
                                      item.precioOverride = null;
                                      _priceControllers[item.id]?.text = _formatPrice(item.precioUnitario);
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total Fila: \$${item.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              OutlinedButton.icon(
                onPressed: _addCustomRow,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Fila Personalizada (Envío, Etiqueta, etc.)'),
              ),
              const SizedBox(height: 25),

              const Text('Resumen & Descuentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descuentoEspecialCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descuento Especial General (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.discount_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _envioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Costo de Envío (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _anticipoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Anticipo / Abono (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Agregar IVA (16%)'),
                value: _applyIVA,
                onChanged: (val) => setState(() => _applyIVA = val),
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.black,
              ),
              const SizedBox(height: 5),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text('\$${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Descuento Especial:'),
                        Text('-\$${_descuentoEspecial.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    if (_applyIVA) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('IVA (16%):'),
                          Text('+\$${_iva.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange)),
                        ],
                      ),
                    ],
                    if (_envio > 0 || _applyIVA) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Envío:'),
                          Text('+\$${_envio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL GENERAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('\$${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    if (_anticipo > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Anticipo:'),
                          Text('-\$${_anticipo.toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('RESTANTE PENDIENTE:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('\$${_restante.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateAndSavePdf,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEditing ? 'Guardar Cambios y Generar PDF' : 'Guardar y Generar PDF', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
