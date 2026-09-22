import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// url_launcher not used here
import 'booking_screen.dart';
import 'appointments_history_screen.dart';
import 'client_qr_screen.dart';
import 'staff_qr_scanner_screen.dart';
import 'dashboard_admin.dart';
import 'dashboard_recepcion.dart';
import 'dashboard_super_admin.dart';
import 'admin_branches_screen.dart';
import 'admin_services_screen.dart';
import 'admin_events_screen.dart';
import 'admin_courses_screen.dart';
import 'personal_list_screen.dart';
// edit_profile_screen not used here
import 'profile_screen.dart';
import 'general_config_screen.dart';
import 'api_keys_config_screen.dart';
import '../services/session_provider.dart';
import '../widgets/branches_section.dart';
import '../widgets/products_section.dart';
import '../widgets/services_section.dart';
import '../widgets/background_scaffold.dart';
import 'home_screen.dart';
import '../widgets/promo_slider.dart';
import '../widgets/fidelity_card.dart';
import '../widgets/universal_footer_buttons.dart';
import 'finanzas_personal_screen.dart';
import 'finanzas_recepcion_screen.dart';
import '../widgets/admin_screen_wrapper.dart';
import 'admin_products_screen.dart';
import 'inventario_diario_screen.dart';
import 'proveedores_stock_screen.dart';
import 'admin_clients_screen.dart';
import 'admin_empresas_screen.dart';
import 'create_note_screen.dart';
import 'notas_history_screen.dart';

class HomeLoggedScreen extends StatefulWidget {
  const HomeLoggedScreen({super.key});

  @override
  State<HomeLoggedScreen> createState() => _HomeLoggedScreenState();
}

class _HomeLoggedScreenState extends State<HomeLoggedScreen> {
  final ScrollController _scrollController = ScrollController();
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<SessionProvider>(
        context,
        listen: false,
      ).checkAndRegisterVisit();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);

    if (session.isStaff) {
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('users')
            .stream(primaryKey: ['IDUser'])
            .eq('IDUser', session.userId ?? ''),
        builder: (context, snapshot) {
          final userData = snapshot.data?.isNotEmpty == true
              ? snapshot.data!.first
              : null;

          final bool isAdmin = userData != null
              ? (userData['isAdmin'] ?? false)
              : session.isAdmin;
          final bool isPersonal = userData != null
              ? (userData['isPersonal'] ?? false)
              : session.isPersonal;
          final bool isRecepcion = userData != null
              ? (userData['isRecepcion'] ?? false)
              : session.isRecepcion;
          final bool isRecepcionView = isRecepcion;
          final bool isPersonalView = isPersonal;
          final bool showPersonalBottomBar = isPersonalView || isRecepcionView;

          Widget? drawerWidget;
          if (isAdmin) {
            drawerWidget = _buildDrawer(context, session);
          } else if (isRecepcion) {
            drawerWidget = _buildRecepcionDrawer(context, session);
          }

          return BackgroundScaffold(
            drawerScrimColor: Colors.transparent,
            drawer: drawerWidget,
            endDrawer: null,
            bottomNavigationBar: showPersonalBottomBar
                ? _buildFixedBottomBarPersonal(isRecepcionView, isAdmin)
                : null,
            appBar: AppBar(
              title: const Text(
                'Omar Studio',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.black),
              actions: [
                if (!isAdmin)
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () {
                      session.clearSession();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                  ),
              ],
            ),
            body: _buildStaffView(session, isAdmin, isPersonal, isRecepcion),
          );
        },
      );
    }

    return BackgroundScaffold(
      drawerScrimColor: Colors.transparent,
      endDrawer: _buildClientDrawer(context, session),
      bottomNavigationBar: _buildFixedBottomBar(session),
      body: SafeArea(bottom: false, child: _buildClientHome(session)),
    );
  }

  Widget _buildRecepcionDrawer(BuildContext context, SessionProvider session) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13.5, sigmaY: 13.5),
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
              child: _AnimatedDrawerContent(
                header: const DrawerHeader(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Panel Recepción',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                items: [
                  ListTile(
                    leading: const Icon(
                      Icons.badge_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Gestión del Personal',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminScreenWrapper(
                            title: 'Gestión del Personal',
                            child: PersonalListScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.spa_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Administrar Servicios',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminScreenWrapper(
                            title: 'Administrar Servicios',
                            child: AdminServicesScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.school_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Gestión de Cursos',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminScreenWrapper(
                            title: 'Gestión de Cursos',
                            child: AdminCoursesScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Gestión de Productos',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminProductsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Inventario Diario',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InventarioDiarioScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Stock de Proveedores',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProveedoresStockScreen(),
                        ),
                      );
                    },
                  ),
                ],
                footer: Column(
                  children: [
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () {
                        session.clearSession();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, SessionProvider session) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13.5, sigmaY: 13.5),
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
              child: _AnimatedDrawerContent(
                header: const DrawerHeader(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Panel Administrador',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                items: [
                  ListTile(
                    leading: const Icon(
                      Icons.analytics_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Dashboard Principal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      session.setAdminView('admin');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.badge_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Gestión del Personal',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      session.setAdminView('gestion_personal');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.storefront_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Administrar Sucursales',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      session.setAdminView('sucursales');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.event_note_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Gestión de Eventos',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      session.setAdminView('gestion_eventos');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.school_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Gestión de Cursos',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      session.setAdminView('gestion_cursos');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.spa_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Administrar Servicios',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      session.setAdminView('servicios');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Configuración General',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      session.setAdminView('configuracion_general');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.key_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Claves de APIs / Secretos',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      session.setAdminView('configuracion_apis');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Gestión de Productos',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminProductsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Inventario Diario',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InventarioDiarioScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Stock de Proveedores',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProveedoresStockScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.people_outline_rounded,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Gestión de Clientes',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminClientsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.note_add_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Crear Notas',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateNoteScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.history_edu_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Historial de Notas',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotasHistoryScreen(),
                        ),
                      );
                    },
                  ),

                ],
                footer: Column(
                  children: [
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Mi Perfil',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () {
                        session.clearSession();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaffView(
    SessionProvider session,
    bool isAdmin,
    bool isPersonal,
    bool isRecepcion,
  ) {
    if (isAdmin) {
      switch (session.adminView) {
        case 'personal':
          return const DashboardAdmin();
        case 'gestion_personal':
          return const PersonalListScreen();
        case 'recepcion':
          return const DashboardRecepcion();
        case 'sucursales':
          return const AdminBranchesScreen();
        case 'servicios':
          return const AdminServicesScreen();
        case 'gestion_eventos':
          return const AdminEventsScreen();
        case 'gestion_cursos':
          return const AdminCoursesScreen();
        case 'configuracion_general':
          return const GeneralConfigScreen();
        case 'configuracion_apis':
          return const ApiKeysConfigScreen();
        case 'empresas_entrenadores':
          return const AdminEmpresasScreen();
        default:
          return const DashboardSuperAdmin();
      }
    }
    if (isPersonal) return const DashboardAdmin();
    if (isRecepcion) return const DashboardRecepcion();

    return const Center(child: Text('Sin dashboard asignado'));
  }

  Widget _buildClientHome(SessionProvider session) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: () async {
        setState(() {
          _refreshKey++;
        });
        // Pequeño delay de suavizado visual
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        // Extra padding so content doesn't hide behind the fixed bottom bar
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Padding(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 22,
                bottom: 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.black,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Nombre + email (Expanded para no desbordar)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                          child: Row(
                            children: const [
                              Text(
                                'Ver Perfil',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.blueAccent,
                              ),
                            ],
                          ),
                        ),
                        // Nombre truncado a 15 caracteres
                        Text(
                          () {
                            final name = session.userName ?? 'Sin nombre';
                            return name.length > 15
                                ? '${name.substring(0, 15)}...'
                                : name;
                          }(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          session.userEmail ?? 'Sin telefono',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // ...existing code...
                  ),

                  // Hamburger menu en el mismo row
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(
                        Icons.menu,
                        size: 28,
                        color: Colors.black,
                      ),
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Scrollable Promotion Cards
            const PromoSlider(),
            const SizedBox(height: 30),

            // Fidelity Card
            FidelityCard(key: ValueKey('fidelity_card_$_refreshKey')),
            const SizedBox(height: 30),

            const BranchesSection(),
            const SizedBox(height: 20),
            const ProductsSection(),
            const SizedBox(height: 20),
            const ServicesSection(),
            const SizedBox(height: 40),

            // Universal Footer Buttons
            const UniversalFooterButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Fixed bottom bar for Personal view: Stack con dos contenedores superpuestos ─────────────────
  Widget _buildFixedBottomBarPersonal(bool isRecepcionView, bool isAdmin) {
    return SizedBox(
      height: 146, // negro +15%
      child: Stack(
        children: [
          // ── Contenedor negro: llena todo, texto arriba, esquinas sup redondeadas ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffQrScannerScreen()),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 9),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Escanear QR de cliente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenedor blanco con GIF: pegado ABAJO, 100% ancho ──────────────
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            height: 87, // blanco +18%
            child: GestureDetector(
              onTap: () {
                try {
                  final sessionProv = Provider.of<SessionProvider>(
                    context,
                    listen: false,
                  );
                  final userId = sessionProv.userId;
                  if (userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => (isRecepcionView && !isAdmin)
                            ? FinanzasRecepcionScreen(personalId: userId)
                            : FinanzasPersonalScreen(personalId: userId),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Solo personal puede subir registros'),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al abrir')),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fondo animado GIF
                      Image.asset(
                        'assets/material/de_colores.gif',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.white),
                      ),
                      // Texto encima del GIF
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 28,
                            color: Colors.black,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Subir registro',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
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

  // ── Fixed bottom bar: Stack con dos contenedores superpuestos ─────────────────
  Widget _buildFixedBottomBar(SessionProvider session) {
    return SizedBox(
      height: 146, // negro +15% (127 × 1.15)
      child: Stack(
        children: [
          // ── Contenedor negro: llena todo, texto arriba, esquinas sup redondeadas ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientQrScreen()),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 9), // texto más arriba
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Genera tu QR y obtén puntos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenedor blanco con GIF: pegado ABAJO, 100% ancho ──────────────
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            height: 87, // blanco +18% (74 × 1.18)
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingScreen()),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, // fallback si falla el GIF
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                // ClipRRect para que el GIF respete el borderRadius
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fondo animado GIF
                      Image.asset(
                        'assets/material/de_colores.gif',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.white),
                      ),
                      // Texto encima del GIF
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 28,
                            color: Colors.black,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Agendar Cita',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
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

  Widget _buildClientDrawer(BuildContext context, SessionProvider session) {
    final String destination = session.userEmail ?? 'No registrado';
    final bool isEmail = destination.contains('@');

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13.5, sigmaY: 13.5),
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
              child: SafeArea(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: Supabase.instance.client
                      .from('clientes')
                      .select('correo, sucursal_preferida')
                      .eq('IDCliente', session.userId ?? '')
                      .maybeSingle(),
                  builder: (context, snapshot) {
                    final clientData = snapshot.data;
                    final String? registeredEmail = clientData?['correo'];
                    final String? preferredBranch =
                        clientData?['sucursal_preferida'];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drawer Header / Profile info
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white,
                                child: Text(
                                  session.userName?.isNotEmpty == true
                                      ? session.userName![0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.userName ?? 'Usuario',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Cliente',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (preferredBranch != null &&
                                        preferredBranch.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.storefront,
                                            size: 12,
                                            color: Colors.blueAccent,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              preferredBranch,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.white12,
                        ),

                        // Notification Info Section
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.notifications_active_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Notificaciones',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Tus recordatorios y confirmaciones se enviarán a:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      isEmail
                                          ? Icons.mail_outline
                                          : Icons.phone_iphone,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        destination,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (registeredEmail != null &&
                                    registeredEmail.isNotEmpty &&
                                    registeredEmail.trim().toLowerCase() !=
                                        destination.trim().toLowerCase()) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.mail_outline,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          registeredEmail,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.white12,
                        ),

                        // Menu Options
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.history_rounded,
                                  color: Colors.white,
                                ),
                                title: const Text(
                                  'Mis Citas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white70,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AppointmentsHistoryScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                leading: const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                ),
                                title: const Text(
                                  'Ver Perfil',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white70,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Logout Option at bottom
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.white12,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                session.clearSession();
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                                  (route) => false,
                                );
                              },
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              label: const Text(
                                'Cerrar Sesión',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // unused helper removed
}

// ── Animated Drawer Content: staggered fade+slide for each menu item ──────────
class _AnimatedDrawerContent extends StatefulWidget {
  final Widget header;
  final List<Widget> items;
  final Widget footer;

  const _AnimatedDrawerContent({
    required this.header,
    required this.items,
    required this.footer,
  });

  @override
  State<_AnimatedDrawerContent> createState() => _AnimatedDrawerContentState();
}

class _AnimatedDrawerContentState extends State<_AnimatedDrawerContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _headerFade;
  late final List<Animation<double>> _itemFades;
  late final List<Animation<Offset>> _itemSlides;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    final itemCount = widget.items.length;
    // Total duration scales slightly with item count but stays snappy
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + (itemCount * 40)),
    );

    // Header fades in first (0.0 → 0.25)
    _headerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    // Each item gets a staggered interval
    _itemFades = List.generate(itemCount, (i) {
      final start = 0.15 + (i * 0.55 / itemCount);
      final end = (start + 0.20).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _itemSlides = List.generate(itemCount, (i) {
      final start = 0.15 + (i * 0.55 / itemCount);
      final end = (start + 0.20).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(-0.15, 0.0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    // Footer fades in last
    _footerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Animated header
        FadeTransition(opacity: _headerFade, child: widget.header),
        // Animated list items
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return FadeTransition(
                opacity: _itemFades[index],
                child: SlideTransition(
                  position: _itemSlides[index],
                  child: widget.items[index],
                ),
              );
            },
          ),
        ),
        // Animated footer
        FadeTransition(opacity: _footerFade, child: widget.footer),
      ],
    );
  }
}
