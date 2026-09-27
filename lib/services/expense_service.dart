import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseService {
  final _supabase = Supabase.instance.client;

  // Menarik data pengeluaran, diurutkan dari yang terbaru
  Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      return await _supabase
          .from('expenses')
          .select()
          .order('tanggal', ascending: false);
    } catch (e) {
      throw Exception('Gagal menarik data pengeluaran: $e');
    }
  }

  // Menambah data pengeluaran baru dengan tanggal kustom
  Future<void> addExpense(String kategori, int harga, String keterangan, DateTime tanggal) async {
    try {
      await _supabase.from('expenses').insert({
        'tanggal': tanggal.toUtc().toIso8601String(), // Dikonversi ke UTC agar aman dari timezone
        'kategori': kategori,
        'harga': harga,
        'keterangan': keterangan,
      });
    } catch (e) {
      throw Exception('Gagal menambah pengeluaran: $e');
    }
  }

  // FUNGSI BARU: Mengedit pengeluaran
  Future<void> editExpense(int id, String kategori, int harga, String keterangan, DateTime tanggal) async {
    try {
      await _supabase.from('expenses').update({
        'tanggal': tanggal.toUtc().toIso8601String(),
        'kategori': kategori,
        'harga': harga,
        'keterangan': keterangan,
      }).eq('id', id);
    } catch (e) {
      throw Exception('Gagal mengedit pengeluaran: $e');
    }
  }

  // FUNGSI BARU: Menghapus pengeluaran
  Future<void> deleteExpense(int id) async {
    try {
      await _supabase.from('expenses').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus pengeluaran: $e');
    }
  }
}