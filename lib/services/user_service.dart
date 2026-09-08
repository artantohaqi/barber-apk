import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  // Menambahkan parameter currentUserRoleId
  Future<List<Map<String, dynamic>>> getUsers(int currentUserRoleId) async {
    try {
      // 1. Base Query (Hanya select)
      var query = _supabase
          .from('users')
          .select('id, username, is_active, role_id, roles(role_name)');
          
      // 2. Filter (Wajib sebelum order)
      if (currentUserRoleId == 2) {
        query = query.eq('role_id', 3);
      }
      
      // 3. Modifier (.order diletakkan paling akhir sebelum di-await)
      return await query.order('id', ascending: true);
    } catch (e) {
      throw Exception('Gagal menarik data user: $e');
    }
  }

  Future<void> createUser(String username, String password, int roleId) async {
    try {
      await _supabase.rpc('create_new_user', params: {
        'p_username': username,
        'p_password': password,
        'p_role_id': roleId,
      });
    } catch (e) {
      throw Exception('Gagal membuat user: $e');
    }
  }

  // FITUR BARU: Edit Data User Dasar
  Future<void> editUser(int userId, String username, int roleId) async {
    try {
      await _supabase.from('users').update({
        'username': username,
        'role_id': roleId,
      }).eq('id', userId);

      // Logika Sinkronisasi: Jika role diubah menjadi Barber (3)
      if (roleId == 3) {
        final check = await _supabase.from('barbers').select('id').eq('user_id', userId);
        if (check.isEmpty) {
          await _supabase.from('barbers').insert({'user_id': userId, 'is_active': true});
        } else {
          await _supabase.from('barbers').update({'is_active': true}).eq('user_id', userId);
        }
      } else {
        // Jika diubah dari Barber ke Kasir/Owner, hilangkan dari layar POS
        await _supabase.from('barbers').update({'is_active': false}).eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Gagal mengedit user: $e');
    }
  }

  // FITUR BARU: Toggle Slider Aktif/Nonaktif
  Future<void> toggleUserStatus(int userId, int roleId, bool isActive) async {
    try {
      await _supabase.from('users').update({'is_active': isActive}).eq('id', userId);
      
      // Jika dia Barber, matikan juga di tabel barbers
      if (roleId == 3) {
        await _supabase.from('barbers').update({'is_active': isActive}).eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Gagal mengubah status: $e');
    }
  }
}