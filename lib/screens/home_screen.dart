import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';
import '../widgets/banner_section.dart';
import '../widgets/branches_section.dart';
import '../widgets/products_section.dart';
import '../widgets/services_section.dart';
import '../widgets/background_scaffold.dart';
import '../widgets/universal_footer_buttons.dart';
import 'login_screen.dart';
import 'home_logged_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showContactBtn = false;
  final String _contactPhone = '+528334539727';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<SessionProvider>(context, listen: false).checkAndRegisterVisit();
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final double progress =
          _scrollController.position.pixels /
          _scrollController.position.maxScrollExtent;
      if (progress >= 0.25 && !_showContactBtn) {
        setState(() => _showContactBtn = true);
      } else if (progress < 0.25 && _showContactBtn) {
        setState(() => _showContactBtn = false);
      }
    }
  }

  Future<void> _makeCall() async {
    final Uri url = Uri.parse('tel:$_contactPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede iniciar la llamada')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // iOS cleaner look
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.person, color: Colors.black),
              label: const Text(
                'Ingresar',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BannerSection(),

              const BranchesSection(),
              const SizedBox(height: 20),
              const ProductsSection(),
              const SizedBox(height: 20),
              const ServicesSection(),
              const SizedBox(height: 40),
              const UniversalFooterButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: _showContactBtn
          ? FloatingActionButton.extended(
              onPressed: _makeCall,
              backgroundColor: Colors.black,
              icon: const Icon(Icons.phone, color: Colors.white),
              label: const Text(
                'Llámanos',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}

