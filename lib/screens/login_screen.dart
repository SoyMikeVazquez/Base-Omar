import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/session_provider.dart';
import '../services/email_service.dart';
import '../widgets/custom_text_field.dart';
import 'home_logged_screen.dart';
import 'forgot_password_screen.dart';

// ════════════════════════════════════════════════════
// LOGIN SCREEN – Slider top + login card bottom
// ════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Client Tab Logic ---
  bool _isUsingPhone = true;
  final _clientContactController = TextEditingController();

  // --- Staff Tab Logic ---
  final _staffEmailController = TextEditingController();
  final _staffPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clientContactController.dispose();
    _staffEmailController.dispose();
    _staffPasswordController.dispose();
    super.dispose();
  }

  // Quick access for clients via DB validation
  Future<void> _handleClientAccess() async {
    final contact = _clientContactController.text.trim();

    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa el campo para continuar.'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('clientes')
          .select()
          .or('telefono.eq.$contact,correo.eq.$contact')
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aún no se ha registrado como cliente, debe hacerlo.',
            ),
            backgroundColor: Color(0xFFC53A00),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final session = Provider.of<SessionProvider>(context, listen: false);
      await session.setClientSession(
        userId: response['IDCliente'],
        name: response['nombre'] ?? 'Cliente',
        email: response[_isUsingPhone ? 'telefono' : 'correo'] ?? contact,
        branch: response['sucursal_preferida'] ?? '',
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeLoggedScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al validar acceso: $e')));
    }
  }

  void _showRegisterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _RegisterClientSheet(),
    );
  }

  Future<void> _handleStaffAccess() async {
    final email = _staffEmailController.text.trim();
    final password = _staffPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa las credenciales.')),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null)
        throw Exception('No se pudo obtener el usuario.');

      final userData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('IDUser', response.user!.id)
          .eq('IDEmpresa', 'FRFROIJNU821')
          .maybeSingle();

      if (userData == null) {
        throw Exception(
          'Usuario no encontrado en la base de datos de personal.',
        );
      }

      final session = Provider.of<SessionProvider>(context, listen: false);
      await session.setStaffSession(
        userId: userData['IDUser'] ?? response.user!.id,
        name: userData['nombre'] ?? 'Personal',
        email: email,
        isPersonal: userData['isPersonal'] ?? false,
        isAdmin: userData['isAdmin'] ?? false,
        isRecepcion: userData['isRecepcion'] ?? false,
        isGestor: userData['isGestor'] ?? false,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeLoggedScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de acceso: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    }
  }

  Future<void> _openWebLink(String columnName) async {
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo abrir el enlace: $url')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El enlace no está configurado en General'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener el enlace: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Slider covering the whole screen
          Positioned.fill(
            child: _LoginImageSlider(onBack: () => Navigator.of(context).pop()),
          ),

          // 2. Smooth Continuous Dark Gradient Overlay (transparent at top, deep black at bottom)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.50),
                      Colors.black.withOpacity(0.90),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Login Panel content overlaying the gradient on the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: bottomInset > 0 ? bottomInset + 10 : 20,
                ),
                child: SizedBox(
                  height:
                      410, // height for login card
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Tab bar selector — compact & transparent dark
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.white60,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            unselectedLabelStyle: const TextStyle(fontSize: 13),
                            tabs: const [
                              Tab(text: 'Cliente'),
                              Tab(text: 'Personal'),
                            ],
                          ),
                        ),
                      ),

                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [_buildClientTab(), _buildStaffTab()],
                        ),
                      ),


                      // Footer Row for Support and Privacy Links
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _openWebLink('Soporte'),
                              child: const Text(
                                'Soporte',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              '|',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _openWebLink('PoliticaDePrivacidad'),
                              child: const Text(
                                'Política de privacidad',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dark-styled text field with embedded icon toggles
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: TextField(
              controller: _clientContactController,
              style: const TextStyle(color: Colors.white, height: 1.2),
              keyboardType: _isUsingPhone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              maxLength: _isUsingPhone ? 10 : null,
              inputFormatters: _isUsingPhone
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              decoration: InputDecoration(
                labelText: _isUsingPhone
                    ? 'Número de Teléfono'
                    : 'Correo Electrónico',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: _isUsingPhone
                    ? '10 dígitos sin espacios'
                    : 'ejemplo@correo.com',
                hintStyle: const TextStyle(color: Colors.white70),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: Icon(
                  _isUsingPhone ? Icons.phone : Icons.email,
                  color: Colors.white54,
                ),
                prefixText: _isUsingPhone ? '52 ' : null,
                prefixStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phone toggle
                    GestureDetector(
                      onTap: () => setState(() {
                        _isUsingPhone = true;
                        _clientContactController.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 4),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isUsingPhone
                              ? Colors.white
                              : Colors.white.withOpacity(0.15),
                        ),
                        child: Icon(
                          Icons.phone_android,
                          size: 15,
                          color: _isUsingPhone ? Colors.black : Colors.white54,
                        ),
                      ),
                    ),
                    // Email toggle
                    GestureDetector(
                      onTap: () => setState(() {
                        _isUsingPhone = false;
                        _clientContactController.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 10),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: !_isUsingPhone
                              ? Colors.white
                              : Colors.white.withOpacity(0.15),
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          size: 15,
                          color: !_isUsingPhone ? Colors.black : Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Acceder button — white on dark
          ElevatedButton(
            onPressed: _handleClientAccess,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Acceder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '¿Nunca has hecho una cita? ',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              GestureDetector(
                onTap: _showRegisterSheet,
                child: const Text(
                  'Regístrate',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Entrar como invitado',
                style: TextStyle(
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white70,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Acceso para personal del negocio',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Email field — dark styled
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: TextField(
              controller: _staffEmailController,
              style: const TextStyle(color: Colors.white, height: 1.2),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'ejemplo@correo.com',
                hintStyle: TextStyle(color: Colors.white30),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: Icon(Icons.email_outlined, color: Colors.white54),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Password field — dark styled
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: TextField(
              controller: _staffPasswordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, height: 1.2),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: const TextStyle(color: Colors.white54),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Colors.white54,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white54,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
                );
              },
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Iniciar sesión — white button
          ElevatedButton(
            onPressed: _handleStaffAccess,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Iniciar Sesión',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),

          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Entrar como invitado',
                style: TextStyle(
                  color: Colors.white54,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// IMAGE SLIDER WIDGET: fetches images from General
// ════════════════════════════════════════════════════
class _LoginImageSlider extends StatefulWidget {
  final VoidCallback onBack;

  const _LoginImageSlider({required this.onBack});

  @override
  State<_LoginImageSlider> createState() => _LoginImageSliderState();
}

class _LoginImageSliderState extends State<_LoginImageSlider> {
  final PageController _pageController = PageController();
  List<String> _images = [];
  bool _isLoading = true;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    try {
      final data = await Supabase.instance.client
          .from('General')
          .select(
            'imagenSlider1, imagenSlider2, imagenSlider3, LogoDeLaEmpresa, imagePortada',
          )
          .limit(1)
          .maybeSingle();

      final List<String> images = [];
      if (data != null) {
        final img1 = data['imagenSlider1']?.toString().trim();
        final img2 = data['imagenSlider2']?.toString().trim();
        final img3 = data['imagenSlider3']?.toString().trim();
        if (img1 != null && img1.isNotEmpty) images.add(img1);
        if (img2 != null && img2.isNotEmpty) images.add(img2);
        if (img3 != null && img3.isNotEmpty) images.add(img3);

        // Fallback to LogoDeLaEmpresa/imagePortada if all slider columns are empty
        if (images.isEmpty) {
          final logo = data['LogoDeLaEmpresa']?.toString().trim();
          final portada = data['imagePortada']?.toString().trim();
          if (logo != null && logo.isNotEmpty) images.add(logo);
          if (portada != null && portada.isNotEmpty) images.add(portada);
        }
      }

      if (mounted) {
        setState(() {
          _images = images;
          _isLoading = false;
        });
        if (_images.length > 1) _startAutoScroll();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _images.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Slide content ──
        if (_isLoading)
          _buildPlaceholder()
        else if (_images.isEmpty)
          _buildPlaceholder()
        else
          PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) {
              return CachedNetworkImage(
                imageUrl: _images[i],
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              );
            },
          ),

        // ── Bottom gradient overlay ──
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.transparent,
                    Colors.black.withOpacity(0.45),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ── Back button ──
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: SafeArea(
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),

        // ── Page indicators ──
        if (_images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_images.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.storefront_outlined, color: Colors.white24, size: 64),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// BOTTOM SHEET: Client registration saves to 'clientes' table
// ════════════════════════════════════════════════════
class _RegisterClientSheet extends StatefulWidget {
  const _RegisterClientSheet();

  @override
  State<_RegisterClientSheet> createState() => _RegisterClientSheetState();
}

class _RegisterClientSheetState extends State<_RegisterClientSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedBranch;
  bool _isLoading = false;

  List<String> _branches = [];
  bool _isLoadingBranches = true;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await Supabase.instance.client
          .from('Sucursales')
          .select('NombreSucursal')
          .eq('IDGeneral', 'FRFROIJNU821')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal Canarios')
          .neq('NombreSucursal', 'Omar´s Barber - Sucursal florida')
          .order('NombreSucursal', ascending: true);

      final branchNames = List<String>.from(
        (response as List).map((b) => b['NombreSucursal'] as String),
      );

      if (mounted) {
        setState(() {
          _branches = branchNames;
          _isLoadingBranches = false;
          if (_branches.contains("Omar's Barber - Sucursal Montealto")) {
            _selectedBranch = "Omar's Barber - Sucursal Montealto";
          } else if (_branches.isNotEmpty) {
            _selectedBranch = _branches[0];
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBranches = false);
      debugPrint('Error fetching branches: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _registerClient() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || phone.isEmpty || _selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos obligatorios.'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final insertResp = await Supabase.instance.client
          .from('clientes')
          .insert({
            'nombre': name,
            'telefono': phone,
            'correo': email.isEmpty ? null : email,
            'sucursal_preferida': _selectedBranch,
          })
          .select()
          .single();

      if (email.isNotEmpty) {
        () async {
          try {
            await EmailService.sendWelcomeEmail(
              toEmail: email,
              clientName: name,
            );
          } catch (e) {
            debugPrint('Error sending welcome email: $e');
          }
        }();
      }

      if (!mounted) return;

      final session = Provider.of<SessionProvider>(context, listen: false);
      await session.setClientSession(
        userId: insertResp['IDCliente'],
        name: name,
        email: phone,
        branch: _selectedBranch!,
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeLoggedScreen()),
        (route) => false,
      );
    } on PostgrestException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar: ${e.message}')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Crea tu perfil',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          CustomTextField(
            controller: _nameController,
            label: 'Nombre completo',
            hint: 'Tu nombre',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          CustomTextField(
            controller: _phoneController,
            label: 'Teléfono (WhatsApp)',
            hint: 'Solo 10 dígitos',
            prefixIcon: Icons.message,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          CustomTextField(
            controller: _emailController,
            label: 'Correo electrónico (Opcional)',
            hint: 'ejemplo@correo.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 55,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoadingBranches
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBranch,
                      hint: Row(
                        children: const [
                          Icon(Icons.store_outlined, color: Colors.grey),
                          SizedBox(width: 12),
                          Text(
                            'Sucursal preferida',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      isExpanded: true,
                      items: [
                        for (final branch in _branches)
                          DropdownMenuItem<String>(
                            value: branch,
                            child: Text(branch),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedBranch = value),
                    ),
                  ),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: _isLoading ? null : _registerClient,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Registrarme',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
