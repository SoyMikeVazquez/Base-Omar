import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'section_header.dart';

class BranchesSection extends StatelessWidget {
  const BranchesSection({super.key});

  Future<List<Map<String, dynamic>>> _fetchBranches() async {
    final response = await Supabase.instance.client
        .from('Sucursales')
        .select()
        .eq('IDGeneral', 'FRFROIJNU821')
        .neq('NombreSucursal', 'Omar´s Barber - Sucursal Canarios')
        .neq('NombreSucursal', 'Omar´s Barber - Sucursal florida')
        .order('NombreSucursal', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _launchMaps(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Sucursales'),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBranches(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 350,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const SizedBox(
                height: 100,
                child: Center(child: Text('No hay sucursales disponibles.')),
              );
            }

            final branches = snapshot.data!;

            return SizedBox(
              height: 350,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: branches.length,
                itemBuilder: (context, index) {
                  final branch = branches[index];
                  final name = branch['NombreSucursal'] ?? 'Sin nombre';
                  final location = branch['Ubicación'] ?? 'Sin ubicación';
                  final imageUrl =
                      branch['FotoSucucrsal']; // Fixed typo from DB schema
                  final mapsUrl = branch['UbicaciónLink'];

                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 16, bottom: 20),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Background Image
                          if (imageUrl != null &&
                              imageUrl.toString().isNotEmpty)
                            Positioned.fill(
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => _buildPlaceholder(),
                                errorWidget: (context, url, error) => _buildPlaceholder(),
                              ),
                            )
                          else
                            _buildPlaceholder(),

                          // Overlay Gradient for readability
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  location,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () => _launchMaps(mapsUrl),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      45,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Ver en maps',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.store_outlined, color: Colors.black12, size: 60),
      ),
    );
  }
}
