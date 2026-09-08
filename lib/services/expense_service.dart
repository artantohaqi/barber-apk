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

  // Menambah data pengeluaran baru
  Future<void> addExpense(String kategori, int harga, String keterangan) async {
    try {
      await _supabase.from('expenses').insert({
        'tanggal': DateTime.now().toIso8601String(),
        'kategori': kategori,
        'harga': harga,
        'keterangan': keterangan,
      });
    } catch (e) {
      throw Exception('Gagal menambah pengeluaran: $e');
    }
  }
}