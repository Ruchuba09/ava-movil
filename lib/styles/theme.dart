import 'package:flutter/material.dart';
import 'colors.dart';

ThemeData temaApp() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: whiteColor,
    canvasColor: whiteColor,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FastSlideFadeTransition(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    primaryColor: verde5Color,
    colorScheme: ColorScheme.fromSeed(
      seedColor: whiteColor,
      primary: verde5Color,
      onPrimary: whiteColor,
      secondary: Colors.grey,
      surface: whiteColor,
      onSurface: black0Color,
      brightness: Brightness.light,
    ),
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: black0Color,
      foregroundColor: whiteColor,
      centerTitle: true,
      elevation: 0,
      iconTheme: IconThemeData(color: whiteColor),
    ),
    dialogTheme: DialogThemeData(backgroundColor: whiteColor),
  );
}

class _FastSlideFadeTransition extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.05, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(
        opacity: curved,
        child: child,
      ),
    );
  }
}
