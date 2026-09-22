import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      if (session.userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final table = session.isStaff ? 'users' : 'clientes';
      final idColumn = session.isStaff ? 'IDUser' : 'IDCliente';

      var query = Supabase.instance.client.from(table).select();
      
      if (session.userId != null) {
        query = query.eq(idColumn, session.userId!);
      } else if (session.userEmail != null) {
        query = query.eq('correo', session.userEmail!);
      } else {
        setState(() => _isLoading = false);
        return;
      }

      final response = await query.single();

      if (mounted) {
        setState(() {
          _userData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
              _loadProfileData(); // Reload data after editing
            },
            child: const Text(
              'Editar',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Photo
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.black12,
                      backgroundImage: (_userData?['fotoperfil'] ?? _userData?['foto_perfil']) != null
                          ? NetworkImage((_userData!['fotoperfil'] ?? _userData!['foto_perfil']).toString())
                          : null,
                      child: (_userData?['fotoperfil'] ?? _userData?['foto_perfil']) == null
                          ? const Icon(Icons.person, size: 60, color: Colors.black26)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // User Info Cards
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    label: 'Nombre completo',
                    value: _userData?['nombre'] ?? 'Sin nombre',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: _userData?['correo'] ?? 'Sin correo',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.phone_android,
                    label: 'Teléfono',
                    value: _userData?['telefono'] ?? _userData?['whatsapp'] ?? 'Sin teléfono',
                  ),
                  
                  if (!Provider.of<SessionProvider>(context).isStaff) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.store_outlined,
                      label: 'Sucursal preferida',
                      value: _userData?['sucursal_preferida'] ?? 'No especificada',
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
