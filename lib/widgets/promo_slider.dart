import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PromoSlider extends StatefulWidget {
  const PromoSlider({super.key});

  @override
  State<PromoSlider> createState() => _PromoSliderState();
}

class _PromoSliderState extends State<PromoSlider> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _eventos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEventos();
  }

  Future<void> _fetchEventos() async {
    try {
      final response = await _supabase
          .from('Eventos')
          .select('imagenDeEvento, TituloDeEvento, DescripcionDelEvento, FechaDeEvento');

      final todos = List<Map<String, dynamic>>.from(response);
      final conImagen = todos.where((e) {
        final img = e['imagenDeEvento'];
        return img != null && img.toString().trim().isNotEmpty;
      }).toList();

      // Sort by date in Dart to avoid column-null issues
      conImagen.sort((a, b) {
        final fa = a['FechaDeEvento']?.toString() ?? '';
        final fb = b['FechaDeEvento']?.toString() ?? '';
        return fa.compareTo(fb);
      });

      setState(() {
        _eventos = conImagen;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar eventos: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 275,
        child: Center(child: CircularProgressIndicator(color: Colors.black12)),
      );
    }
    if (_error != null || _eventos.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 275,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _eventos.length,
        itemBuilder: (context, index) => _EventCard(evento: _eventos[index]),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> evento;

  const _EventCard({required this.evento});

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = evento['imagenDeEvento'] ?? '';
    final String titulo = evento['TituloDeEvento'] ?? '';
    final String descripcion = evento['DescripcionDelEvento'] ?? '';
    final String fecha = _formatDate(evento['FechaDeEvento']?.toString());

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16, bottom: 8, top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.black12,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white24),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(Icons.event, size: 60, color: Colors.black26),
                ),
              ),
            ),

            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF), // Vidrio translúcido esmerilado
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top row: label + date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Ver más aquí',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (fecha.isNotEmpty)
                              Text(
                                fecha,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Title
                        if (titulo.isNotEmpty)
                          Text(
                            titulo.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // Description
                        if (descripcion.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            descripcion,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
