import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_provider.dart';
import '../screens/home_screen.dart';

class UniversalFooterButtons extends StatelessWidget {
  const UniversalFooterButtons({super.key});

  Future<void> _openWebLink(BuildContext context, String columnName) async {
    try {
      final generalData = await Supabase.instance.client
          .from('General')
          .select(columnName)
          .limit(1)
          .maybeSingle();
      
      final url = generalData?[columnName]?.toString().trim();
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo abrir el enlace: $url')),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El enlace no está configurado en General')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener el enlace: $e')),
        );
      }
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context, SessionProvider session) async {
    // First warning dialog
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '¿Eliminar tu cuenta?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Esta acción es irreversible y se eliminarán todos tus datos de registro. ¿Estás completamente seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black87)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, continuar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    if (!context.mounted) return;

    // Second warning dialog
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Confirmación Definitiva',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: const Text(
          'ADVERTENCIA: Esta es la última confirmación. Se borrará tu correo y registro de clientes de forma permanente. ¿Proceder con la eliminación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black87)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar permanentemente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm2 != true) return;

    if (!context.mounted) return;

    // Perform deletion with a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      final userId = session.userId;
      final userEmail = session.userEmail;

      // 1. Delete client record from public.clientes
      if (userId != null && userId.isNotEmpty) {
        await client.from('clientes').delete().eq('IDCliente', userId);
      } else if (userEmail != null && userEmail.isNotEmpty) {
        await client.from('clientes').delete().or('telefono.eq.$userEmail,correo.eq.$userEmail');
      }

      // 2. Delete Auth user from auth.users (if logged in through gotrue auth)
      if (currentUser != null) {
        try {
          await client.rpc('delete_user_account');
        } catch (e) {
          debugPrint('Error running delete_user_account RPC: $e');
        }
        await client.auth.signOut();
      }

      // 3. Clear session local state
      await session.clearSession();

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu cuenta ha sido eliminada con éxito.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la cuenta: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    
    return Column(
      children: [
        _buildButton(
          label: 'Información de soporte, contacto y quejas',
          onTap: () => _openWebLink(context, 'Soporte'),
        ),
        _buildButton(
          label: 'Politicas de privacidad',
          onTap: () => _openWebLink(context, 'PoliticaDePrivacidad'),
        ),
        if (session.isLoggedIn) ...[
          _buildButton(
            label: 'Eliminar y deshabilitar cuenta',
            textColor: const Color(0xFFC53A00),
            onTap: () => _handleDeleteAccount(context, session),
          ),
        ],
      ],
    );
  }

  Widget _buildButton({required String label, Color? textColor, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.95),
          foregroundColor: textColor ?? Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 4,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
