import 'package:supabase_flutter/supabase_flutter.dart';

class TreatmentService {
  final _supabase = Supabase.instance.client;

  // Menarik semua data treatment
  Future<List<Map<String, dynamic>>> getTreatments() async {
    try {
      final response = await _supabase
          .from('treatments')
          .select()
          .order('id', ascending: true);
      return response;
    } catch (e) {
      throw Exception('Gagal menarik data layanan: $e');
    }
  }

  // Menambah treatment baru
  Future<void> addTreatment(String nama, int waktu, int harga, int komisi) async {
    try {
      await _supabase.from('treatments').insert({
        'treatment': nama,
        'waktu_menit': waktu,
        'harga': harga,
        'komisi': komisi,
      });
    } catch (e) {
      throw Exception('Gagal menambah layanan: $e');
    }
  }

  // Mengubah data treatment (termasuk Soft Delete via is_active)
  Future<void> updateTreatment(int id, String nama, int waktu, int harga, int komisi, bool isActive) async {
    try {
      await _supabase.from('treatments').update({
        'treatment': nama,
        'waktu_menit': waktu,
        'harga': harga,
        'komisi': komisi,
        'is_active': isActive,
      }).eq('id', id);
    } catch (e) {
      throw Exception('Gagal memperbarui layanan: $e');
    }
  }
}