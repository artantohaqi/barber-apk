import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final String dummyEmail = '$username@binkas.com'.toLowerCase();

      // 1. Eksekusi Login ke Supabase Auth (Gerbang Depan)
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: dummyEmail,
        password: password,
      );

      if (res.user == null) return null;

      // 2. Tarik role_id DAN is_active dari tabel public.users
      final userData = await _supabase
          .from('users')
          .select('id, username, role_id, is_active') // TAMBAHAN: Menarik status aktif
          .eq('username', username)
          .single();

      // 3. LOGIKA PEMBLOKIRAN
      if (userData['is_active'] == false) {
        // Hancurkan token sesi seketika agar mereka tidak bisa menembus API RLS
        await _supabase.auth.signOut();
        throw Exception('Akun Anda telah dinonaktifkan oleh Owner.');
      }

      return userData; 
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      // Menangkap pesan error custom kita agar rapi ditampilkan ke SnackBar UI
      if (e.toString().contains('dinonaktifkan')) {
        throw Exception('Akun Anda telah dinonaktifkan oleh Owner.');
      }
      throw Exception('Terjadi kesalahan sistem: $e');
    }
  }
}