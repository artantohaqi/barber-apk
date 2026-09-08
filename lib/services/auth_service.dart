import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Fungsi ini mengembalikan Map berisi id dan role_id jika sukses, atau null jika gagal
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      // Memanggil fungsi 'login_user' di PostgreSQL via RPC
      final response = await _supabase.rpc('login_user', params: {
        'p_username': username,
        'p_password': password,
      });

      // Jika response tidak kosong (ada data cocok)
      if (response != null && (response as List).isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return null; // Username atau password salah
    } catch (e) {
      throw Exception('Terjadi kesalahan saat login: $e');
    }
  }
}