import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
    
    final startOfMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)).toUtc().toIso8601String();

    // 1. Metrik Hari Ini
    final paymentsToday = await _supabase.from('payments').select('id, total_harga').gte('jadwal', startOfDay).lte('jadwal', endOfDay);
    final expensesToday = await _supabase.from('expenses').select('harga').gte('tanggal', startOfDay).lte('tanggal', endOfDay);
    
    int incomeToday = paymentsToday.fold(0, (sum, i) => sum + (i['total_harga'] as int));
    int expenseToday = expensesToday.fold(0, (sum, i) => sum + (i['harga'] as int));
    int customersToday = paymentsToday.length;

    // 2. Trend Pemasukan Bulan Ini
    final paymentsMonth = await _supabase.from('payments').select('jadwal, total_harga').gte('jadwal', startOfMonth).order('jadwal', ascending: true);
    Map<int, int> trendData = {}; // Map tanggal (day) ke total income
    for (var p in paymentsMonth) {
      final date = DateTime.parse(p['jadwal']).toLocal();
      trendData[date.day] = (trendData[date.day] ?? 0) + (p['total_harga'] as int);
    }

    // 3. Treatment Populer Minggu Ini
    final popTreatments = await _supabase
      .from('order_details')
      .select('jumlah, payments!inner(jadwal), treatments(treatment)')
      .gte('payments.jadwal', startOfWeek);

    Map<String, int> treatmentCounts = {};
    for (var t in popTreatments) {
      String name = t['treatments']['treatment'];
      treatmentCounts[name] = (treatmentCounts[name] ?? 0) + (t['jumlah'] as int);
    }
    var sortedTreatments = treatmentCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return {
      'incomeToday': incomeToday,
      'expenseToday': expenseToday,
      'customersToday': customersToday,
      'trendData': trendData,
      'popularTreatments': sortedTreatments.take(5).toList(), // Ambil top 5
    };
  }
}