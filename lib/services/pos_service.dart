import 'package:supabase_flutter/supabase_flutter.dart';

class PosService {
  final _supabase = Supabase.instance.client;

  // Menarik data barber aktif beserta nama username-nya dari tabel users
  // Sintaks 'users!inner(username)' adalah cara Supabase melakukan operasi JOIN SQL
  Future<List<Map<String, dynamic>>> getActiveBarbers() async {
    try {
      final response = await _supabase
          .from('barbers')
          .select('id, users!inner(username)')
          .eq('is_active', true)
          .order('id', ascending: true);
      return response;
    } catch (e) {
      throw Exception('Gagal menarik data Barber: $e');
    }
  }

  // Menarik data treatment yang sedang aktif
  Future<List<Map<String, dynamic>>> getActiveTreatments() async {
    try {
      final response = await _supabase
          .from('treatments')
          .select()
          .eq('is_active', true)
          .order('treatment', ascending: true);
      return response;
    } catch (e) {
      throw Exception('Gagal menarik data Layanan: $e');
    }
  }
}