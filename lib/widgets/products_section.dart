import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'section_header.dart';

class ProductsSection extends StatelessWidget {
  const ProductsSection({super.key});

  Future<Map<String, dynamic>> _fetchData() async {
    final productsResp = await Supabase.instance.client
        .from('Productos')
        .select()
        .or('disponible_venta.eq.true,isDisponibleVenta.eq.true')
        .order('NombreProducto', ascending: true);

    final generalResp = await Supabase.instance.client
        .from('General')
        .select('verPreciosProductos')
        .limit(1)
        .maybeSingle();

    return {
      'products': List<Map<String, dynamic>>.from(productsResp),
      'verPreciosProductos': generalResp?['verPreciosProductos'] ?? false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Productos'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'En nuestro negocio lo puedes adquirir.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 350,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox(
                height: 350,
                child: Center(
                  child: Text('No hay productos disponibles por el momento.'),
                ),
              );
            }

            final data = snapshot.data!;
            final products = data['products'] as List<Map<String, dynamic>>;
            final verPrecios = data['verPreciosProductos'] as bool;

            if (products.isEmpty) {
              return const SizedBox(
                height: 350,
                child: Center(
                  child: Text('No hay productos disponibles por el momento.'),
                ),
              );
            }

            return SizedBox(
              height: 350,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final name = product['nombre'] ?? product['NombreProducto'] ?? 'Sin nombre';
                  final price = product['precio'] ?? product['montoProducto'] ?? 0;
                  final imageUrl = product['imagen_url'] ?? product['ImagenProducto'];
                  final enOferta = product['en_oferta'] ?? product['isDescuento'] ?? false;

                  return Container(
                    width: 220,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child:
                                imageUrl != null &&
                                    imageUrl.toString().isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        _buildPlaceholder(),
                                    errorWidget: (context, url, error) =>
                                        _buildPlaceholder(),
                                  )
                                : _buildPlaceholder(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (enOferta)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: const Text(
                                    'Tiene descuento',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (verPrecios) ...[
                                const SizedBox(height: 12),
                                Text(
                                  '\$$price',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                '.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
      color: Colors.grey[100],
      child: const Icon(
        Icons.shopping_bag_outlined,
        color: Colors.black12,
        size: 40,
      ),
    );
  }
}
