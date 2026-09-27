import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    // Memberi jeda 2 detik agar layar pemuatan / logo sempat terlihat
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 1. Cek memori lokal HP: Apakah ada tiket sesi Supabase yang masih aktif?
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null && session.user.email != null) {
        // 2. Jika ada, ekstrak username dari email bayangan (contoh: kasir@binkas.com -> kasir)
        final String username = session.user.email!.split('@')[0];

        // 3. Tarik role_id dan status aktif dari public.users menggunakan tiket tersebut
        final userData = await Supabase.instance.client
            .from('users')
            .select('role_id, is_active')
            .eq('username', username)
            .single();

        // 4. Validasi Keamanan: Jika Owner memblokir akun ini saat aplikasi ditutup
        if (userData['is_active'] == false) {
          await Supabase.instance.client.auth.signOut();
          _goToLogin();
          return;
        }

        // 5. Sesi Valid: Langsung tembus ke Dashboard tanpa perlu ketik password
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(roleId: userData['role_id'])),
        );
      } else {
        // Tiket kosong (belum pernah login / sudah logout manual)
        _goToLogin();
      }
    } catch (e) {
      // Jika token rusak, internet mati, atau error lainnya, amankan dengan melempar ke layar Login
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey, 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Jika masalah aset gambar sudah teratasi, Anda bisa mengganti ikon ini dengan:
            // Image.asset('assets/images/logo.jpg', height: 120),
            const Icon(Icons.cut, size: 80, color: Colors.white), 
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            const Text('Menghubungkan ke server...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}