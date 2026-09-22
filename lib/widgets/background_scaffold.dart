import 'package:flutter/material.dart';

class BackgroundScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? drawerScrimColor;

  const BackgroundScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawerScrimColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base de fondo blanco puro
        Positioned.fill(
          child: Container(
            color: Colors.white,
          ),
        ),
        
        // GIF Background
        Positioned.fill(
          child: Opacity(
            opacity: 0.5, // Ajustado para que sea muy blanco y limpio sin perder el dinamismo de las ondas
            child: Image.asset(
              'assets/material/fondo.gif',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.white,
                );
              },
            ),
          ),
        ),
        
        // Actual Screen Content
        Scaffold(
          backgroundColor: Colors.transparent, // Very important
          appBar: appBar,
          drawer: drawer,
          endDrawer: endDrawer,
          drawerScrimColor: drawerScrimColor,
          body: body,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ],
    );
  }
}

