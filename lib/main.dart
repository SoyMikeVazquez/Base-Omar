import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/home_logged_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/session_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  await Supabase.initialize(
    url: 'https://zxkvyajmvkxufsogsrug.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4a3Z5YWptdmt4dWZzb2dzcnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODk2NTM1MDksImV4cCI6MjAwNTIyOTUwOX0.tKgbmVvqZMU2hywCbhYWSVKXLU8VKrACH4Ez8oGSULk',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => SessionProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final StreamSubscription<AuthState> _authSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => const ResetPasswordScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        if (!session.isInitialized) {
          return MaterialApp(
            title: 'Omar Studio',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            home: const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        return MaterialApp(
          navigatorKey: _navigatorKey,
          key: ValueKey(session.isLoggedIn),
          title: 'Omar Studio',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          home: session.isLoggedIn
              ? const HomeLoggedScreen()
              : const HomeScreen(),
        );
      },
    );
  }

  ThemeData _buildTheme() {
    // SF Pro is the native Apple font — works natively on iOS/macOS.
    // On web (Safari/macOS) it maps to the system font via -apple-system.
    // Fallback: SF Pro → -apple-system → Helvetica Neue → Arial → sans-serif
    const String sfPro = '.SF Pro Display';
    const List<String> fontFallback = [
      '-apple-system',
      'BlinkMacSystemFont',
      'SF Pro Display',
      'Helvetica Neue',
      'Arial',
      'sans-serif',
    ];

    const Color black = Colors.black;
    const Color white = Colors.white;

    return ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: Colors.transparent,

      // Color scheme — everything anchored to black
      colorScheme: const ColorScheme.light(
        primary: black,
        onPrimary: white,
        secondary: Colors.black87,
        onSecondary: white,
        tertiary: Colors.black54,
        surface: white,
        onSurface: black,
        error: black,
        onError: white,
      ),

      // Typography — SF Pro everywhere
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
        ),
        bodyMedium: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
        ),
        bodySmall: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: Colors.black54,
        ),
        labelLarge: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: Colors.black54,
        ),
        labelSmall: TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: Colors.black38,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: white,
        foregroundColor: black,
        elevation: 0,
        shadowColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle
            .dark, // Hace los íconos de la barra de estado negros
        titleTextStyle: const TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          color: black,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: black),
        actionsIconTheme: const IconThemeData(color: black),
      ),

      // ElevatedButton → black bg / white text
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: black,
          foregroundColor: white,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: sfPro,
            fontFamilyFallback: fontFallback,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),

      // OutlinedButton → black border / black text
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: black,
          side: const BorderSide(color: black),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // TextButton → black
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: black),
      ),

      // FloatingActionButton → black
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 4,
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: white,
        unselectedLabelColor: Colors.black54,
        indicator: BoxDecoration(
          color: black,
          borderRadius: BorderRadius.circular(25),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
          fontWeight: FontWeight.w600,
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: black,
        contentTextStyle: const TextStyle(
          color: white,
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
        ),
        actionTextColor: Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade200,
        selectedColor: black,
        labelStyle: const TextStyle(
          color: black,
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
        ),
        secondaryLabelStyle: const TextStyle(
          color: white,
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? black : white,
        ),
        side: const BorderSide(color: black, width: 1.5),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? black : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.black38
              : Colors.grey.shade300,
        ),
      ),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: black,
        linearTrackColor: Color(0xFFE5E5E5),
        circularTrackColor: Color(0xFFE5E5E5),
      ),

      // Icons
      iconTheme: const IconThemeData(color: black),
      primaryIconTheme: const IconThemeData(color: black),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: black, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
        ),
        hintStyle: const TextStyle(
          color: Colors.black38,
          fontFamily: sfPro,
          fontFamilyFallback: fontFallback,
        ),
        prefixIconColor: Colors.black54,
        suffixIconColor: Colors.black54,
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(backgroundColor: white),

      // ListTile
      listTileTheme: const ListTileThemeData(
        iconColor: black,
        textColor: black,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEEEEEE),
        thickness: 1,
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
