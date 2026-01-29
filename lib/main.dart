// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Ekranlar
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/personel_list_screen.dart';
import 'screens/attachment_screen.dart';
import 'screens/payroll_form_screen.dart';

// Uygulama ayarları (tema)
import 'shared/app_settings.dart';
import 'shared/settings_prefs.dart';

// (İsteğe bağlı: bordro düzenlemede initial arg kullanıyorsan)
// import 'models/payroll.dart';

const kBilsoftBlue = Color(0xFF0B3D91); // lacivert
const kBilsoftOrange = Color(0xFFF7931E); // vurgu (opsiyonel)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kalıcı tema ayarını yükle
  final themeMode = await SettingsPrefs.loadTheme();

  final appSettings = AppSettings();
  appSettings.setThemeMode(themeMode);

  runApp(
    ChangeNotifierProvider(
      create: (_) => appSettings,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: kBilsoftBlue,
        secondary: kBilsoftOrange,
        background: Colors.white,
        surface: Colors.white,
        onPrimary: Colors.white,
        onBackground: Colors.black87,
        onSurface: Colors.black87,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: kBilsoftBlue,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kBilsoftBlue,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kBilsoftBlue),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: kBilsoftBlue, width: 2),
        ),
        prefixIconColor: kBilsoftBlue,
      ),
    );
  }

  ThemeData _darkTheme() {
    // Basit koyu tema
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kBilsoftBlue,
        brightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Personel Takip',

      // Tema kontrolü
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: settings.themeMode,

      // Tek dil (Türkçe) — localization kaldırıldı
      initialRoute: '/login',

      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/personel': (_) => const PersonelListScreen(),
      },

      onGenerateRoute: (settingsRoute) {
        switch (settingsRoute.name) {
          case '/attachments':
            {
              final args = settingsRoute.arguments;
              if (args is Map && args['personnelId'] is int) {
                return MaterialPageRoute(
                  builder: (_) =>
                      AttachmentScreen(personnelId: args['personnelId'] as int),
                  settings: settingsRoute,
                );
              }
              return _errorRoute('Eksik veya hatalı argüman: personnelId');
            }

          case '/payroll-form':
            {
              final args = settingsRoute.arguments;
              if (args is Map &&
                  args['personnelId'] is int &&
                  args['period'] is String) {
                return MaterialPageRoute(
                  builder: (_) => PayrollFormScreen(
                    personnelId: args['personnelId'] as int,
                    initialPeriod: args['period'] as String,
                    initial: args['initial'], // null olabilir
                  ),
                  settings: settingsRoute,
                );
              }
              return _errorRoute(
                  'Eksik veya hatalı argüman: personnelId / period');
            }
        }
        return null;
      },
    );
  }

  Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
