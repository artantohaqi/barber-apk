import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUsers(int currentUserRoleId) async {
    try {
      var query = _supabase
          .from('users')
          .select('id, username, is_active, role_id, roles(role_name)');
          
      if (currentUserRoleId == 2) {
        query = query.eq('role_id', 3);
      }
      
      return await query.order('id', ascending: true);
    } catch (e) {
      throw Exception('Gagal menarik data user: $e');
    }
  }

  Future<void> createUser(String username, String password, int roleId) async {
    try {
      final ghostClient = SupabaseClient(
        'https://azfanpxgsesbczyxdxob.supabase.co',
        'sb_publishable_YukE_NKrMdF-sZfLW2elvQ_J6G4JN2F',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit, 
        ),
      );

      final String dummyEmail = '$username@binkas.com'.toLowerCase();

      await ghostClient.auth.signUp(
        email: dummyEmail,
        password: password,
      );

      ghostClient.dispose();

      await _supabase.rpc('create_new_user', params: {
        'p_username': username,
        'p_password': password, 
        'p_role_id': roleId,
      });
      
    } catch (e) {
      throw Exception('Gagal membuat pegawai baru: $e');
    }
  }

  Future<void> editUser(int userId, String username, int roleId) async {
    try {
      await _supabase.from('users').update({
        'username': username,
        'role_id': roleId,
      }).eq('id', userId);

      if (roleId == 3) {
        final check = await _supabase.from('barbers').select('id').eq('user_id', userId);
        if (check.isEmpty) {
          await _supabase.from('barbers').insert({'user_id': userId, 'is_active': true});
        } else {
          await _supabase.from('barbers').update({'is_active': true}).eq('user_id', userId);
        }
      } else {
        await _supabase.from('barbers').update({'is_active': false}).eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Gagal mengedit user: $e');
    }
  }

  Future<void> toggleUserStatus(int userId, int roleId, bool isActive) async {
    try {
      await _supabase.from('users').update({'is_active': isActive}).eq('id', userId);
      
      if (roleId == 3) {
        await _supabase.from('barbers').update({'is_active': isActive}).eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Gagal mengubah status: $e');
    }
  }
}