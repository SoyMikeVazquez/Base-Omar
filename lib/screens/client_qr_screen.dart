import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_provider.dart';

class ClientQrScreen extends StatefulWidget {
  const ClientQrScreen({super.key});

  @override
  State<ClientQrScreen> createState() => _ClientQrScreenState();
}

class _ClientQrScreenState extends State<ClientQrScreen> {
  String? _qrToken;
  int _puntos = 0;
  int _puntosMeta = 6;
  DateTime? _puntosApertura;
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh countdown every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _estaBloqueado) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (session.userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      // 1. Consultar datos del cliente
      final dataCliente = await Supabase.instance.client
          .from('clientes')
          .select('qr_token, puntos, puntos_apertura')
          .eq('IDCliente', session.userId!)
          .single();

      // 2. Consultar la meta global en la tabla General
      final dataGeneral = await Supabase.instance.client
          .from('General')
          .select('PUNTOSALCOMPLETAR')
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _qrToken = (dataCliente['qr_token'] as String?) ?? session.userId;
          _puntos = (dataCliente['puntos'] as int?) ?? 0;
          
          // Leemos dinámicamente PUNTOSALCOMPLETAR de la tabla General
          double? metaGeneralDouble;
          if (dataGeneral != null && dataGeneral['PUNTOSALCOMPLETAR'] != null) {
            metaGeneralDouble = double.tryParse(dataGeneral['PUNTOSALCOMPLETAR'].toString());
          }
          _puntosMeta = metaGeneralDouble?.toInt() ?? 6;
          
          debugPrint('=== QR CLIENTE === PUNTOS METAS CARGADOS DESDE SUPABASE: $_puntosMeta');
          
          final String? aperturaStr = dataCliente['puntos_apertura'] as String?;
          _puntosApertura = aperturaStr != null
              ? DateTime.parse(aperturaStr)
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading QR data: $e');
      if (mounted) {
        setState(() {
          _qrToken = session.userId;
          _isLoading = false;
        });
      }
    }
  }

  bool get _estaBloqueado {
    if (_puntosApertura == null) return false;
    return DateTime.now().isBefore(_puntosApertura!);
  }

  String get _tiempoRestante {
    if (_puntosApertura == null) return '';
    final now = DateTime.now();
    if (now.isAfter(_puntosApertura!)) return '';
    final diff = _puntosApertura!.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      final seconds = diff.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }

  String _formatHoy() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return '$day//$month//$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Mi código QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final bool bloqueado = _estaBloqueado;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Instrucción ─────────────────────────────────────────────────
          const Text(
            'Muéstrale este QR al personal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Se añadirá 1 estrella a tu tarjeta de fidelidad (máximo 1 por día)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── QR Code ──────────────────────────────────────────────────────
          if (_qrToken != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bloqueado ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: bloqueado
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    data: '$_qrToken|${_formatHoy()}',
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                  // Overlay cuando ya escaneó hoy (bloqueado)
                  if (bloqueado)
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.greenAccent,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '¡Punto obtenido!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Próximo en: $_tiempoRestante',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
          else
            const Text(
              'No se encontró tu QR.\nContacta al administrador.',
              style: TextStyle(color: Colors.red, fontSize: 15),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 32),

          // ── Contador de estrellas ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                Text(
                  '$_puntos / $_puntosMeta',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const Text(
                  'estrellas acumuladas',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 16),
                // Stars visual
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_puntosMeta, (i) {
                    final filled = i < _puntos;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: filled ? Colors.amber : Colors.white24,
                      size: 30,
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Estado de hoy ────────────────────────────────────────────
          if (bloqueado)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ya obtuviste tu estrella de hoy. Siguiente escaneo disponible en $_tiempoRestante',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pueden escanear tus puntos una vez al día. Pide al personal que escanee tu QR.',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
