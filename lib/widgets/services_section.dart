import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/booking_screen.dart';
import 'section_header.dart';

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});

  Future<Map<String, dynamic>> _fetchData() async {
    final servicesResp = await Supabase.instance.client
        .from('Services')
        .select()
        .order('created_at', ascending: true);
    
    final generalResp = await Supabase.instance.client
        .from('General')
        .select('verPreciosServicios')
        .limit(1)
        .maybeSingle();

    return {
      'services': List<Map<String, dynamic>>.from(servicesResp),
      'verPreciosServicios': generalResp?['verPreciosServicios'] ?? false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Catálogo de servicios'),
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No hay servicios disponibles por el momento.'),
              );
            }

            final data = snapshot.data!;
            final services = data['services'] as List<Map<String, dynamic>>;
            final verPrecios = data['verPreciosServicios'] as bool;

            if (services.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No hay servicios disponibles por el momento.'),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final name = service['nameService'] ?? 'Sin nombre';
                final price = service['Price'] ?? 0;
                final imageUrl = service['ImageService'];

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingScreen(initialService: service),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: imageUrl != null && imageUrl.toString().isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => _buildPlaceholder(),
                                    errorWidget: (context, url, error) => _buildPlaceholder(),
                                  )
                                : _buildPlaceholder(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (verPrecios) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '\$$price',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                'Agendar ahora', // Changed from "Ver más"
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: const Icon(Icons.cut, color: Colors.black12, size: 40),
    );
  }
}
