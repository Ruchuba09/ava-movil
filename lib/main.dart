import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/home/home_screen.dart';
import 'package:avamovil/view/auth/login_screen.dart';
import 'package:avamovil/controller/theme_controller.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    
    return MaterialApp(
      title: 'AVA Móvil',
      debugShowCheckedModeBanner: false,
      themeMode: themeController.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verde5Color,
          brightness: Brightness.light,
          primary: verde5Color,
          secondary: gris2Color,
          surface: verde1Color,
        ),
        fontFamily: 'Montserrat',
        appBarTheme: const AppBarTheme(
          backgroundColor: whiteColor,
          foregroundColor: blackColor,
          elevation: 0,
        ),
        scaffoldBackgroundColor: verde1Color,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verde5Color,
          brightness: Brightness.dark,
          primary: verde5Color,
          secondary: verde2Color,
        ),
        fontFamily: 'Montserrat',
        appBarTheme: const AppBarTheme(
          backgroundColor: darkColor,
          foregroundColor: whiteColor,
          elevation: 0,
        ),
        scaffoldBackgroundColor: blackColor,
      ),
      home: const LoginScreen(),
    );
  }
}
