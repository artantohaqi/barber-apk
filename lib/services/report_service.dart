import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getLaporan(DateTime start, DateTime end) async {
    try {
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      final startIso = start.toUtc().toIso8601String();
      final endIso = endOfDay.toUtc().toIso8601String();

      // PERBAIKAN: Menambahkan via_payments(via) untuk menarik nama metode pembayaran secara relasional
      final payments = await _supabase
          .from('payments')
          .select('id, nama, no_hp, via_id, total_harga, jadwal, nama_nota, via_payments(via), order_details(id, treatment_id, barber_id, jumlah, jum_harga, jum_komisi, treatments(treatment, harga, komisi), barbers(id, users(username)))')
          .gte('jadwal', startIso)
          .lte('jadwal', endIso)
          .order('jadwal', ascending: false);

      int totalPemasukan = payments.fold(0, (sum, item) => sum + (item['total_harga'] as int));

      final expenses = await _supabase
          .from('expenses')
          .select('*')
          .gte('tanggal', startIso)
          .lte('tanggal', endIso)
          .order('tanggal', ascending: false);

      int totalPengeluaran = expenses.fold(0, (sum, item) => sum + (item['harga'] as int));

      return {
        'pemasukan': totalPemasukan,
        'pengeluaran': totalPengeluaran,
        'laba_bersih': totalPemasukan - totalPengeluaran,
        'detail_pemasukan': payments,
        'detail_pengeluaran': expenses,
      };
    } catch (e) {
      throw Exception('Gagal menarik laporan: $e');
    }
  }

  // FUNGSI 1: Edit Informasi Master Transaksi (Tanggal, Jam, Nama, Metode Pembayaran)
  Future<void> updateTransactionHeader(int paymentId, String nama, DateTime jadwal, int viaId) async {
    try {
      await _supabase.from('payments').update({
        'nama': nama,
        'jadwal': jadwal.toUtc().toIso8601String(),
        'via_id': viaId,
      }).eq('id', paymentId);
    } catch (e) {
      throw Exception('Gagal memperbarui data transaksi: $e');
    }
  }

  // FUNGSI 2: Menghapus Transaksi Secara Total
  Future<void> deleteTransaction(int paymentId) async {
    try {
      await _supabase.from('order_details').delete().eq('payment_id', paymentId);
      await _supabase.from('payments').delete().eq('id', paymentId);
    } catch (e) {
      throw Exception('Gagal menghapus transaksi: $e');
    }
  }

  // FUNGSI 3: Tambah Layanan ke Transaksi yang Sudah Ada
  Future<void> addTransactionItem({
    required int paymentId,
    required int barberId,
    required Map<String, dynamic> treatment,
    required int jumlah,
  }) async {
    try {
      int totalHargaItem = (treatment['harga'] as int) * jumlah;
      int totalKomisiItem = (treatment['komisi'] as int) * jumlah;

      await _supabase.from('order_details').insert({
        'payment_id': paymentId,
        'barber_id': barberId,
        'treatment_id': treatment['id'],
        'jumlah': jumlah,
        'jum_harga': totalHargaItem,
        'jum_komisi': totalKomisiItem,
      });

      await _recalculateTotal(paymentId);
    } catch (e) {
      throw Exception('Gagal menambah layanan: $e');
    }
  }

  // FUNGSI 4: Hapus Layanan Spesifik
  Future<void> deleteTransactionItem(int paymentId, int orderDetailId) async {
    try {
      await _supabase.from('order_details').delete().eq('id', orderDetailId);
      await _recalculateTotal(paymentId);
    } catch (e) {
      throw Exception('Gagal menghapus layanan: $e');
    }
  }

  // FUNGSI 5: Edit Layanan Spesifik
  Future<void> editTransactionItem({
    required int paymentId,
    required int orderDetailId,
    required int newBarberId,
    required Map<String, dynamic> newTreatment, 
    required int jumlah,
  }) async {
    try {
      int totalHargaItem = (newTreatment['harga'] as int) * jumlah;
      int totalKomisiItem = (newTreatment['komisi'] as int) * jumlah;

      await _supabase.from('order_details').update({
        'barber_id': newBarberId,
        'treatment_id': newTreatment['id'],
        'jum_harga': totalHargaItem,
        'jum_komisi': totalKomisiItem,
      }).eq('id', orderDetailId);

      await _recalculateTotal(paymentId);
    } catch (e) {
      throw Exception('Gagal mengedit transaksi: $e');
    }
  }

  // HELPER: Kalkulasi ulang total harga
  Future<void> _recalculateTotal(int paymentId) async {
    final allItems = await _supabase.from('order_details').select('jum_harga').eq('payment_id', paymentId);
    int newGrandTotal = allItems.fold(0, (sum, item) => sum + (item['jum_harga'] as int));
    await _supabase.from('payments').update({'total_harga': newGrandTotal}).eq('id', paymentId);
  }
}