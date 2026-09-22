import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show File, Directory;
import 'package:intl/intl.dart';
import '../utils/pdf_helper.dart';
import '../services/email_service.dart';
import 'create_note_screen.dart';

class NotasHistoryScreen extends StatefulWidget {
  const NotasHistoryScreen({super.key});

  @override
  State<NotasHistoryScreen> createState() => _NotasHistoryScreenState();
}

class _NotasHistoryScreenState extends State<NotasHistoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<dynamic> _notas = [];
  bool _isLoading = true;
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _fetchNotas();
  }

  Future<void> _fetchNotas() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('notas_venta').select().order('created_at', ascending: false);
      setState(() {
        _notas = res;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar notas: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredNotas {
    if (_filterDate == null) return _notas;
    return _notas.where((n) {
      final d = DateTime.tryParse(n['created_at'] ?? '');
      if (d == null) return false;
      return d.year == _filterDate!.year &&
          d.month == _filterDate!.month &&
          d.day == _filterDate!.day;
    }).toList();
  }

  Future<void> _selectFilterDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _filterDate = picked;
      });
    }
  }

  Future<void> _toggleStatus(String id, bool currentStatus) async {
    if (currentStatus) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelar Documento'),
          content: const Text('¿Estás seguro de que deseas cancelar este documento? Esta acción lo marcará como cancelado.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, mantener'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Sí, cancelar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await _supabase.from('notas_venta').update({'finalizada': !currentStatus}).eq('id', id);
      _fetchNotas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar estado: $e')));
      }
    }
  }

  Future<Uint8List> _generatePdfBytes(Map<String, dynamic> nota) async {
    final int folio = nota['folio'] ?? 1;
    final String clientName = nota['cliente_nombre'] ?? '';
    final String clientAddress = nota['cliente_direccion'] ?? '';
    final String clientPhone = nota['cliente_telefono'] ?? '';
    final String clientEmail = nota['cliente_correo'] ?? '';
    final double total = (nota['total'] as num).toDouble();
    final double subtotal = (nota['subtotal'] as num).toDouble();
    final double descuentoEspecial = (nota['descuento_especial'] as num?)?.toDouble() ?? 0.0;
    final bool aplicaIva = nota['aplica_iva'] == true;
    final double iva = (nota['iva'] as num?)?.toDouble() ?? 0.0;
    final double envio = (nota['envio'] as num?)?.toDouble() ?? 0.0;
    final double anticipo = (nota['anticipo'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> rawItems = nota['items'] ?? [];
    final DateTime date = DateTime.tryParse(nota['created_at'] ?? '') ?? DateTime.now();

    final PdfDocument document = PdfDocument();

    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final PdfFont subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final PdfFont regularFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final PdfFont sectionHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final PdfFont totalsFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final PdfFont bankHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final PdfFont bankBodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final PdfFont condFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5);

    const int itemsPerPage = 7;
    final int totalPages = (rawItems.isEmpty) ? 1 : (rawItems.length / itemsPerPage).ceil();

    Uint8List? topLogoBytes;
    try {
      final ByteData b = await rootBundle.load('assets/logosuperior.png');
      topLogoBytes = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
    } catch (_) {
      try {
        final ByteData b = await rootBundle.load('assets/logo.png');
        topLogoBytes = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
      } catch (_) {}
    }

    Uint8List? watermarkBytes;
    try {
      final ByteData b = await rootBundle.load('assets/marcadeagua.png');
      watermarkBytes = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
    } catch (_) {}

    for (int p = 0; p < totalPages; p++) {
      final PdfPage page = document.pages.add();
      final Size clientSize = page.getClientSize();

      if (watermarkBytes != null) {
        final PdfBitmap watermarkImage = PdfBitmap(watermarkBytes);
        page.graphics.save();
        page.graphics.setTransparency(0.12);
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

      final bool isRecibo = nota['es_recibo'] == true;
      final String tituloDocumento = isRecibo ? 'RECIBO DE CUENTA' : 'PRESUPUESTO';

      page.graphics.drawString('MAQUILA DE PRODUCTOS', titleFont, bounds: Rect.fromLTWH(80, 0, clientSize.width - 80, 22), format: PdfStringFormat(alignment: PdfTextAlignment.center));
      page.graphics.drawString(tituloDocumento, subtitleFont, bounds: Rect.fromLTWH(80, 22, clientSize.width - 80, 18), format: PdfStringFormat(alignment: PdfTextAlignment.center));

      final String folioStr = '${folio.toString().padLeft(4, '0')}-${DateFormat('ddMMyy').format(date)}';
      page.graphics.drawString('Folio: #$folioStr', subtitleFont, bounds: Rect.fromLTWH(0, 45, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));

      final String dayStr = date.day.toString().padLeft(2, '0');
      final String monthStr = date.month.toString().padLeft(2, '0');
      final String formattedDate = '$dayStr/$monthStr/${date.year} ${DateFormat('hh:mm a').format(date)}';
      page.graphics.drawString('Fecha: $formattedDate', boldFont, bounds: Rect.fromLTWH(0, 65, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));

      if (totalPages > 1) {
        page.graphics.drawString('Página ${p + 1} de $totalPages', regularFont, bounds: Rect.fromLTWH(0, 80, clientSize.width, 15), format: PdfStringFormat(alignment: PdfTextAlignment.right));
      }

      double yOffset = 98;
      
      if (aplicaIva) {
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
      page.graphics.drawString('NOMBRE: ${clientName.toUpperCase()}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
      yOffset += 16;
      page.graphics.drawString('DIRECCIÓN: ${clientAddress.toUpperCase()}', regularFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
      yOffset += 16;
      page.graphics.drawString('TELÉFONO: $clientPhone', regularFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
      yOffset += 16;
      if (clientEmail.isNotEmpty) {
        page.graphics.drawString('CORREO: $clientEmail', regularFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16));
        yOffset += 16;
      }

      yOffset += 10;

      final int startIndex = p * itemsPerPage;
      final int endIndex = (startIndex + itemsPerPage < rawItems.length) ? startIndex + itemsPerPage : rawItems.length;
      final pageItems = rawItems.sublist(startIndex, endIndex);

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
        page.graphics.drawString('Subtotal: \$${subtotal.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
        yOffset += 16;
        if (descuentoEspecial > 0) {
          page.graphics.drawString('Descuento Especial: -\$${descuentoEspecial.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
          yOffset += 16;
        }
        if (aplicaIva) {
          page.graphics.drawString('IVA (16%): \$${iva.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
          yOffset += 16;
        }
        if (envio > 0) {
          page.graphics.drawString('Envío: \$${envio.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
          yOffset += 16;
        }
        page.graphics.drawString('TOTAL GENERAL: \$${total.toStringAsFixed(2)}', totalsFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));
        yOffset += 18;

        if (isRecibo) {
          if (anticipo > 0) {
            page.graphics.drawString('Anticipo Registrado: \$${anticipo.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
            yOffset += 16;
          }
          page.graphics.drawString('ESTADO: PAGADO (\$0.00 PENDIENTE)', totalsFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));
        } else if (anticipo > 0) {
          final double restante = (total - anticipo < 0) ? 0.0 : (total - anticipo);
          page.graphics.drawString('Anticipo: \$${anticipo.toStringAsFixed(2)}', boldFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
          yOffset += 16;
          page.graphics.drawString('RESTANTE PENDIENTE: \$${restante.toStringAsFixed(2)}', totalsFont, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 18), format: PdfStringFormat(alignment: PdfTextAlignment.right));
        }
      } else {
        page.graphics.drawString('(Continúa en la siguiente página...)', regularFont, bounds: Rect.fromLTWH(0, clientSize.height - 150, clientSize.width, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
      }

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

    final List<int> savedBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(savedBytes);
  }

  Future<void> _downloadOrSharePdf(Map<String, dynamic> nota) async {
    try {
      final int folio = nota['folio'] ?? 1;
      final bool isRecibo = nota['es_recibo'] == true;
      final String filePrefix = isRecibo ? 'Nota_Venta' : 'Presupuesto';
      final String docTitle = isRecibo ? 'Nota de Venta' : 'Presupuesto';
      final pdfBytes = await _generatePdfBytes(nota);

      final DateTime date = DateTime.tryParse(nota['created_at'] ?? '') ?? DateTime.now();
      final String folioStr = '${folio.toString().padLeft(4, '0')}-${DateFormat('ddMMyy').format(date)}';

      if (kIsWeb) {
        triggerPdfDownloadWeb(pdfBytes, '${filePrefix}_$folioStr.pdf');
      } else {
        final Directory dir = await getApplicationDocumentsDirectory();
        final String path = '${dir.path}/${filePrefix}_$folioStr.pdf';
        final Size size = MediaQuery.of(context).size;
        final Rect shareRect = Rect.fromLTWH(size.width / 2, size.height / 2, 2, 2);
        final File file = File(path);
        await file.writeAsBytes(pdfBytes, flush: true);
        await Share.shareXFiles(
          [XFile(path)],
          text: '$docTitle #$folioStr',
          sharePositionOrigin: shareRect,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
      }
    }
  }

  Future<void> _shareAirDropNative(Map<String, dynamic> nota) async {
    try {
      final int folio = nota['folio'] ?? 1;
      final bool isRecibo = nota['es_recibo'] == true;
      final String filePrefix = isRecibo ? 'Nota_Venta' : 'Presupuesto';
      final String docTitle = isRecibo ? 'Nota de Venta' : 'Presupuesto';
      final pdfBytes = await _generatePdfBytes(nota);

      final DateTime date = DateTime.tryParse(nota['created_at'] ?? '') ?? DateTime.now();
      final String folioStr = '${folio.toString().padLeft(4, '0')}-${DateFormat('ddMMyy').format(date)}';

      if (kIsWeb) {
        try {
          final xFile = XFile.fromData(
            pdfBytes,
            mimeType: 'application/pdf',
            name: '${filePrefix}_$folioStr.pdf',
          );
          await Share.shareXFiles([xFile], text: '$docTitle #$folioStr');
        } catch (_) {
          triggerPdfDownloadWeb(pdfBytes, '${filePrefix}_$folioStr.pdf');
        }
      } else {
        final Directory dir = await getApplicationDocumentsDirectory();
        final String path = '${dir.path}/${filePrefix}_$folioStr.pdf';
        final Size size = MediaQuery.of(context).size;
        final Rect shareRect = Rect.fromLTWH(size.width / 2, size.height / 2, 2, 2);
        final File file = File(path);
        await file.writeAsBytes(pdfBytes, flush: true);
        await Share.shareXFiles(
          [XFile(path)],
          text: '$docTitle #$folioStr',
          sharePositionOrigin: shareRect,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
      }
    }
  }

  Future<void> _sendEmailDialog(Map<String, dynamic> nota) async {
    final TextEditingController emailCtrl = TextEditingController(text: nota['cliente_correo'] ?? '');
    final int folio = nota['folio'] ?? 1;
    final DateTime date = DateTime.tryParse(nota['created_at'] ?? '') ?? DateTime.now();
    final String folioStr = '${folio.toString().padLeft(4, '0')}-${DateFormat('ddMMyy').format(date)}';
    
    final bool isRecibo = nota['es_recibo'] == true;
    final String docTitle = isRecibo ? 'Nota' : 'Presupuesto';

    final bool? shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enviar $docTitle #$folioStr por Correo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa o confirma el correo electrónico del cliente:'),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (shouldSend == true && emailCtrl.text.trim().isNotEmpty) {
      final String to = emailCtrl.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando correo...')));
      
      final bool isRecibo = nota['es_recibo'] == true;
      final pdfBytes = await _generatePdfBytes(nota);
      final result = await EmailService.sendNotaVentaEmailDetailed(
        toEmail: to,
        folioStr: folioStr,
        clientName: nota['cliente_nombre'] ?? '',
        total: (nota['total'] as num).toDouble(),
        items: nota['items'] ?? [],
        isRecibo: isRecibo,
        pdfBytes: pdfBytes,
      );

      if (mounted) {
        if (result.success) {
          if (to != (nota['cliente_correo'] ?? '')) {
            _supabase.from('notas_venta').update({'cliente_correo': to}).eq('id', nota['id']).then((_) => _fetchNotas());
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), duration: const Duration(seconds: 8)));
        }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredNotas;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Historial de Notas', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date Filter Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: Colors.black87),
                          const SizedBox(width: 8),
                          Text(
                            _filterDate == null
                                ? 'Mostrando: Todas las fechas'
                                : 'Filtrado: ${DateFormat('dd/MM/yyyy').format(_filterDate!)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_filterDate != null)
                            IconButton(
                              tooltip: 'Ver todas',
                              icon: const Icon(Icons.close, size: 20, color: Colors.red),
                              onPressed: () => setState(() => _filterDate = null),
                            ),
                          ElevatedButton.icon(
                            onPressed: _selectFilterDate,
                            icon: const Icon(Icons.filter_alt_outlined, size: 16),
                            label: const Text('Filtrar Fecha', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ListView of filtered notes
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Text(
                            _filterDate == null
                                ? 'No hay notas registradas.'
                                : 'No hay notas para la fecha ${DateFormat('dd/MM/yyyy').format(_filterDate!)}.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final nota = filteredList[index];
                            final int folio = nota['folio'] ?? 1;
                            final bool isFinalized = nota['finalizada'] ?? true;
                            final bool isRecibo = nota['es_recibo'] == true;
                            final double total = (nota['total'] as num).toDouble();
                            final DateTime date = DateTime.tryParse(nota['created_at'] ?? '') ?? DateTime.now();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: isFinalized ? Colors.green.shade200 : Colors.red.shade200,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Folio #${folio.toString().padLeft(4, '0')}-${DateFormat('ddMMyy').format(date)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isFinalized 
                                                ? (isRecibo ? Colors.blue.shade100 : Colors.green.shade100) 
                                                : Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isFinalized 
                                                ? (isRecibo ? 'RECIBO' : 'PRESUPUESTO') 
                                                : 'CANCELADA',
                                            style: TextStyle(
                                              color: isFinalized 
                                                  ? (isRecibo ? Colors.blue.shade800 : Colors.green.shade800) 
                                                  : Colors.red.shade800,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Cliente: ${nota['cliente_nombre']}'),
                                    if ((nota['cliente_correo'] ?? '').isNotEmpty)
                                      Text('Correo: ${nota['cliente_correo']}'),
                                    Text('Fecha: ${DateFormat('dd/MM/yyyy hh:mm a').format(date)}'),
                                    const SizedBox(height: 6),
                                    Text('Total: \$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                    const Divider(),
                                    
                                    // Action Buttons Row
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _sendEmailDialog(nota),
                                          icon: const Icon(Icons.email_outlined, size: 15, color: Colors.blue),
                                          label: const Text('Enviar', style: TextStyle(color: Colors.blue, fontSize: 11)),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _downloadOrSharePdf(nota),
                                          icon: const Icon(Icons.download_outlined, size: 15, color: Colors.black),
                                          label: const Text('Descargar', style: TextStyle(color: Colors.black, fontSize: 11)),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _shareAirDropNative(nota),
                                          icon: const Icon(Icons.share_outlined, size: 15, color: Colors.purple),
                                          label: const Text('Compartir', style: TextStyle(color: Colors.purple, fontSize: 11)),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final updated = await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CreateNoteScreen(notaToEdit: nota),
                                              ),
                                            );
                                            if (updated == true || mounted) {
                                              _fetchNotas();
                                            }
                                          },
                                          icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.orange),
                                          label: const Text('Editar', style: TextStyle(color: Colors.orange, fontSize: 11)),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _toggleStatus(nota['id'], isFinalized),
                                          icon: Icon(
                                            isFinalized ? Icons.cancel_outlined : Icons.check_circle_outline,
                                            size: 15,
                                            color: isFinalized ? Colors.red : Colors.green,
                                          ),
                                          label: Text(
                                            isFinalized ? 'Cancelar' : 'Finalizar',
                                            style: TextStyle(color: isFinalized ? Colors.red : Colors.green, fontSize: 11),
                                          ),
                                        ),
                                        if (isFinalized)
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              try {
                                                final bool newReciboState = !isRecibo;
                                                await _supabase.from('notas_venta').update({'es_recibo': newReciboState}).eq('id', nota['id']);
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                    content: Text(newReciboState ? 'Convertido a Recibo de Cuenta exitosamente.' : 'Revertido a Presupuesto exitosamente.'),
                                                  ));
                                                }
                                                _fetchNotas();
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cambiar el estado de recibo/presupuesto.')));
                                                }
                                              }
                                            },
                                            icon: Icon(isRecibo ? Icons.undo : Icons.receipt_long, size: 15, color: isRecibo ? Colors.teal : Colors.blue),
                                            label: Text(
                                              isRecibo ? 'Revertir a Presupuesto' : 'Convertir a Recibo',
                                              style: TextStyle(color: isRecibo ? Colors.teal : Colors.blue, fontSize: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
