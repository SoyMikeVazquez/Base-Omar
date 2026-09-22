import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffQrScannerScreen extends StatefulWidget {
  const StaffQrScannerScreen({super.key});

  @override
  State<StaffQrScannerScreen> createState() => _StaffQrScannerScreenState();
}

class _StaffQrScannerScreenState extends State<StaffQrScannerScreen> {
  bool _isProcessing = false;
  String? _resultMessage;
  bool _isSuccess = false;
  int? _newPoints;
  int? _meta;

  bool _hasCameraPermission = false;
  bool _permissionChecked = false;

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        if (mounted) {
          setState(() {
            _hasCameraPermission = true;
            _permissionChecked = true;
          });
        }
      } else {
        // Solicitamos directamente el permiso nativo de la cámara
        final requestStatus = await Permission.camera.request();
        if (mounted) {
          setState(() {
            _hasCameraPermission = requestStatus.isGranted;
            _permissionChecked = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Permission check failed, falling back: $e');
      if (mounted) {
        setState(() {
          _hasCameraPermission = true;
          _permissionChecked = true;
        });
      }
    }
  }

  Future<void> _processQrToken(String token) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _resultMessage = null;
    });

    try {
      // Parse token: check if it contains the anti-fraud date payload
      String clientIdentifier = token.trim();
      String? qrDate;

      if (clientIdentifier.contains('|')) {
        final parts = clientIdentifier.split('|');
        clientIdentifier = parts[0].trim();
        qrDate = parts[1].trim();
      }

      // Check date validity to prevent screenshots/old codes
      final now = DateTime.now();
      final day = now.day.toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final year = now.year.toString();
      final String hoyStaff = '$day//$month//$year';

      if (qrDate != null && qrDate != hoyStaff) {
        _showResult(
          success: false,
          message:
              'Código QR expirado (captura antigua). Pídele al cliente abrir la app.',
        );
        return;
      }

      // 1. Find client by IDCliente (UUID) or qr_token
      Map<String, dynamic>? clientData;

      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      final bool isValidUuid = uuidRegex.hasMatch(clientIdentifier);

      if (isValidUuid) {
        clientData = await Supabase.instance.client
            .from('clientes')
            .select('IDCliente, nombre, puntos, puntos_meta, puntos_apertura')
            .eq('IDCliente', clientIdentifier)
            .maybeSingle();
      }

      if (clientData == null) {
        clientData = await Supabase.instance.client
            .from('clientes')
            .select('IDCliente, nombre, puntos, puntos_meta, puntos_apertura')
            .eq('qr_token', clientIdentifier)
            .maybeSingle();
      }

      if (clientData == null) {
        _showResult(
          success: false,
          message:
              'QR no reconocido. Este código no pertenece a ningún cliente.',
        );
        return;
      }

      // 2. Check if locked (puntos_apertura is in the future)
      final String? puntosAperturaStr =
          clientData['puntos_apertura'] as String?;
      if (puntosAperturaStr != null) {
        final puntosApertura = DateTime.parse(puntosAperturaStr).toLocal();
        final now = DateTime.now();
        if (now.isBefore(puntosApertura)) {
          final diff = puntosApertura.difference(now);
          final hours = diff.inHours;
          final minutes = diff.inMinutes % 60;
          final seconds = diff.inSeconds % 60;

          String timeStr;
          if (hours > 0) {
            timeStr = '${hours}h y ${minutes}m';
          } else if (minutes > 0) {
            timeStr = '${minutes}m y ${seconds}s';
          } else {
            timeStr = '${seconds}s';
          }

          _showResult(
            success: false,
            message:
                '${clientData['nombre']} debe esperar $timeStr para escanear de nuevo.',
          );
          return;
        }
      }

      // 3. Add 1 point and lock for the next 24 hours
      final int puntosActuales = (clientData['puntos'] as int?) ?? 0;
      final int puntosNuevos = puntosActuales + 1;
      
      // Consultar la meta global en la tabla General
      int puntsMeta = 6;
      try {
        final dataGeneral = await Supabase.instance.client
            .from('General')
            .select('PUNTOSALCOMPLETAR')
            .limit(1)
            .maybeSingle();
        if (dataGeneral != null && dataGeneral['PUNTOSALCOMPLETAR'] != null) {
          final double? metaDouble = double.tryParse(dataGeneral['PUNTOSALCOMPLETAR'].toString());
          if (metaDouble != null) {
            puntsMeta = metaDouble.toInt();
          }
        }
      } catch (e) {
        debugPrint('Error fetching puntos meta from General: $e');
        puntsMeta = (clientData['puntos_meta'] as int?) ?? 6;
      }

      final DateTime siguienteApertura = DateTime.now().add(
        const Duration(hours: 24),
      );

      await Supabase.instance.client
          .from('clientes')
          .update({
            'puntos': puntosNuevos,
            'puntos_apertura': siguienteApertura.toIso8601String(),
          })
          .eq('IDCliente', clientData['IDCliente']);

      _showResult(
        success: true,
        message: puntosNuevos >= puntsMeta
            ? '¡${clientData['nombre']} completó su tarjeta! Ya puede canjear su premio 🏆'
            : '+1 estrella para ${clientData['nombre']}',
        newPoints: puntosNuevos,
        meta: puntsMeta,
      );
    } catch (e) {
      _showResult(
        success: false,
        message: 'Error de conexión. Intenta de nuevo.',
      );
      debugPrint('QR scan error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showResult({
    required bool success,
    required String message,
    int? newPoints,
    int? meta,
  }) {
    setState(() {
      _isSuccess = success;
      _resultMessage = message;
      _newPoints = newPoints;
      _meta = meta;
    });

    // Auto-clear after 5 seconds and resume scanning
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _resultMessage = null;
          _newPoints = null;
          _meta = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Escanear QR de Cliente',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          if (_hasCameraPermission)
            IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.white),
              onPressed: () => _controller.toggleTorch(),
            ),
        ],
      ),
      body: !_permissionChecked
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : (!_hasCameraPermission
                ? _buildNoPermissionView()
                : _buildScannerView()),
    );
  }

  Widget _buildNoPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white10,
              child: Icon(
                Icons.videocam_off_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Acceso a la cámara requerido',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Para poder escanear los códigos QR de los clientes, por favor otorga permiso de cámara. Usaremos tus imágenes solo para escanear y personalizar servicios.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _checkPermission(),
              child: const Text(
                'Otorgar Permiso',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text(
                'Abrir Ajustes del Sistema',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        // ── Camera scanner ───────────────────────────────────────────
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final rawValue = capture.barcodes.firstOrNull?.rawValue;
            if (rawValue != null && !_isProcessing) {
              _processQrToken(rawValue);
            }
          },
        ),

        // ── Scan frame overlay ────────────────────────────────────────
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // ── Instructions ─────────────────────────────────────────────
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Apunta al QR del cliente',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),

        // ── Processing indicator ──────────────────────────────────────
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

        // ── Result overlay ────────────────────────────────────────────
        if (_resultMessage != null)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _resultMessage != null ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green[900] : Colors.red[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSuccess ? Colors.green : Colors.red)
                          .withOpacity(0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSuccess
                          ? Icons.star_rounded
                          : Icons.error_outline_rounded,
                      color: _isSuccess ? Colors.amber : Colors.redAccent,
                      size: 44,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _resultMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // Points progress bar when success
                    if (_isSuccess && _newPoints != null && _meta != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_meta!, (i) {
                          final filled = i < _newPoints!;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: filled ? Colors.amber : Colors.white30,
                              size: 26,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_newPoints / $_meta estrellas',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
