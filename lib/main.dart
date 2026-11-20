// lib/main.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/welcome/welcome_screen.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Barra de estado transparente sobre fondo oscuro
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Inicializar locale para formato de fechas y moneda en PDF
    await initializeDateFormatting('es_PE');
    await initializeDateFormatting('es');

    // Manejo global de excepciones de renderizado (Crash prevention ISO/IEC 25010)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher Error: $error');
      return true; // Previene cuelgues no controlados
    };

    // ErrorWidget amigable para el usuario sin pantalla roja
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: const Color(0xFF060C18),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF00E5FF), size: 48),
                const SizedBox(height: 12),
                Text(
                  'EJARAD TIC - Modo de Recuperación',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Se contuvo una excepción técnica de interfaz de manera segura.',
                  style: GoogleFonts.inter(color: const Color(0xFF8899AA), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    };

    await Supabase.initialize(
      url: 'https://mtlwfvnsghoysqksebbo.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im10bHdmdm5zZ2hveXNxa3NlYmJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1Njg1NjYsImV4cCI6MjEwNDE0NDU2Nn0.kB6cbKU4ckAXeNAchD0i9n5bQ37ZvbdyNWnUV9XWlTg',
    );

    runApp(const EjaradApp());
  }, (error, stackTrace) {
    debugPrint('Excepción no interceptada capturada en runZonedGuarded: $error');
  });
}

class EjaradApp extends StatelessWidget {
  const EjaradApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EJARAD TIC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D1A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2979FF),
          brightness: Brightness.dark,
          primary: const Color(0xFF2979FF),
          secondary: const Color(0xFF00E5FF),
          surface: const Color(0xFF111827),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        // Texto blanco por defecto: con fondo primary el texto heredaba el
        // mismo azul y quedaba invisible.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}
