import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
// import 'screens/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';

void main() async {
  // Wajib dipanggil sebelum inisialisasi yang lain
  WidgetsFlutterBinding.ensureInitialized();

  // Membangun koneksi ke Supabase
  await Supabase.initialize(
    url: 'https://azfanpxgsesbczyxdxob.supabase.co',
    publishableKey: 'sb_publishable_YukE_NKrMdF-sZfLW2elvQ_J6G4JN2F',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barbershop POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      // Mendaftarkan rute layar
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
      },
    );
  }
}