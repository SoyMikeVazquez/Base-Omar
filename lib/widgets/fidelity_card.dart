import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_provider.dart';

class FidelityCard extends StatefulWidget {
  const FidelityCard({super.key});

  @override
  State<FidelityCard> createState() => _FidelityCardState();
}

class _FidelityCardState extends State<FidelityCard> {
  int _puntos = 0;
  int _puntosMeta = 6;
  String? _ultimoCanjeo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPuntos();
  }

  Future<void> _fetchPuntos() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (session.userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    if (session.userId == 'demo-client-id') {
      setState(() {
        _puntos = 4;
        _puntosMeta = 6;
        _ultimoCanjeo = DateTime.now().subtract(const Duration(days: 5)).toIso8601String();
        _isLoading = false;
      });
      return;
    }
    try {
      // 1. Consultar los puntos del cliente
      final dataCliente = await Supabase.instance.client
          .from('clientes')
          .select('puntos, ultimo_canjeo')
          .eq('IDCliente', session.userId!)
          .single();

      // 2. Consultar la meta global de puntos desde la tabla General
      final dataGeneral = await Supabase.instance.client
          .from('General')
          .select('PUNTOSALCOMPLETAR')
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _puntos = (dataCliente['puntos'] as int?) ?? 0;
          
          // Leemos dinámicamente PUNTOSALCOMPLETAR del único row en General
          double? metaGeneralDouble;
          if (dataGeneral != null && dataGeneral['PUNTOSALCOMPLETAR'] != null) {
            metaGeneralDouble = double.tryParse(dataGeneral['PUNTOSALCOMPLETAR'].toString());
          }
          _puntosMeta = metaGeneralDouble?.toInt() ?? 6;
          
          debugPrint('=== FIDELIDAD === PUNTOS METAS CARGADOS DESDE SUPABASE: $_puntosMeta');
          
          _ultimoCanjeo = dataCliente['ultimo_canjeo'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching puntos fidelidad: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _canjearPremio(SessionProvider session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🏆 Canjear Premio', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Muestra esta pantalla al personal para que confirme tu premio. ¿Deseas canjear ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('¡Canjear!'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    if (session.userId == 'demo-client-id') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏆 [DEMO] ¡Premio canjeado con éxito! Tu tarjeta ha sido reiniciada.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _puntos = 0;
        });
      }
      return;
    }

    try {
      await Supabase.instance.client.from('clientes').update({
        'puntos': 0,
        'ultimo_canjeo': DateTime.now().toIso8601String(),
      }).eq('IDCliente', session.userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏆 ¡Premio canjeado! Tu tarjeta ha sido reiniciada.'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchPuntos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al canjear. Intenta de nuevo.')),
        );
      }
    }
  }

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _showRecompensaDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        );
      },
    );

    try {
      final data = await Supabase.instance.client
          .from('General')
          .select('RecompensaTituloPuntos, RecompensaDescripcionPuntos')
          .limit(1)
          .maybeSingle();

      // Cerrar indicador de carga
      if (mounted) Navigator.of(context).pop();

      final String titulo = (data != null && data['RecompensaTituloPuntos'] != null)
          ? data['RecompensaTituloPuntos'].toString()
          : 'Recompensa de Puntos';
      final String descripcion = (data != null && data['RecompensaDescripcionPuntos'] != null)
          ? data['RecompensaDescripcionPuntos'].toString()
          : '¡Sigue acumulando puntos para canjear tu próximo premio!';

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      descripcion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      // Cerrar indicador de carga si sigue abierto
      if (mounted) Navigator.of(context).pop();
      
      debugPrint('Error fetching reward details: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar la recompensa. Revisa tu conexión.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        final bool premioDisponible = _puntos >= _puntosMeta && _puntosMeta > 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: premioDisponible
                      ? const LinearGradient(
                          colors: [Color(0xFF1A1A00), Color(0xFF3D2C00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: premioDisponible ? null : Colors.black.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: premioDisponible
                      ? Border.all(color: Colors.amber, width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: premioDisponible
                          ? Colors.amber.withOpacity(0.35)
                          : Colors.black.withOpacity(0.2),
                      blurRadius: premioDisponible ? 24 : 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ───────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  premioDisponible ? '¡Premio listo! 🏆' : 'Tarjeta de fidelidad',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: premioDisponible ? Colors.amber : Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: premioDisponible
                                    ? () => _canjearPremio(session)
                                    : () => _showRecompensaDialog(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: premioDisponible ? Colors.amber : Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: premioDisponible ? 6 : 2,
                                ),
                                child: Text(
                                  premioDisponible ? '¡Canjear!' : 'Ver recompensa',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Body: info + stars ────────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.userName ?? 'Sin nombre',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      session.userEmail ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Función de la tarjeta',
                                      style: TextStyle(fontSize: 13, color: Colors.white60),
                                    ),
                                    Text(
                                      _ultimoCanjeo != null
                                          ? _formatFecha(_ultimoCanjeo!)
                                          : 'Recopila las estrellas y obtén tu recompensa',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ── Stars grid ─────────────────────────────
                              _buildStarsGrid(premioDisponible),
                            ],
                          ),

                          // ── Premio banner ─────────────────────────────────
                          if (premioDisponible) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.4)),
                              ),
                              child: const Text(
                                '¡Felicidades! Muestra esta pantalla al personal para canjear tu premio.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Pueden haber promociones que duren solo un tiempo, por lo que en ocasiones se pueden reiniciar los puntos a 0.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'Si no cuentas con conexión, puedes usar tus puntos en otra ocasión.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarsGrid(bool premioDisponible) {
    // Dynamic grid based on _puntosMeta
    final rows = (_puntosMeta / 3).ceil();
    return Column(
      children: List.generate(rows, (rowIndex) {
        final start = rowIndex * 3;
        final end = (start + 3).clamp(0, _puntosMeta);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(end - start, (colIndex) {
            final starIndex = start + colIndex;
            return _buildStar(starIndex < _puntos, premioDisponible);
          }),
        );
      }),
    );
  }

  Widget _buildStar(bool filled, bool premioDisponible) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: filled
            ? (premioDisponible ? Colors.amber : Colors.amber[700])
            : Colors.grey.withOpacity(0.3),
        shape: BoxShape.circle,
        border: Border.all(
          color: filled
              ? (premioDisponible ? Colors.amber[300]! : Colors.amber[600]!)
              : Colors.white24,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(premioDisponible ? 0.5 : 0.3),
                  blurRadius: premioDisponible ? 12 : 6,
                )
              ]
            : null,
      ),
      child: Icon(
        Icons.star_rounded,
        color: filled ? Colors.white : Colors.white30,
        size: 24,
      ),
    );
  }
}
