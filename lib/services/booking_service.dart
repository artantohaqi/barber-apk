import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/pdf_service.dart'; // Import Pabrik PDF kita

class BookingService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getBookings() async {
    try {
      return await _supabase
          .from('bookings')
          .select('*, barbers(users(username))')
          .eq('status', 'aktif'); 
    } catch (e) {
      throw Exception('Gagal menarik data booking: $e');
    }
  }

  Future<bool> isOverlap(int? barberId, DateTime mulai, DateTime selesai, {int? excludeBookingId}) async {
    if (barberId == null) return false; 

    var query = _supabase.from('bookings')
        .select('id')
        .eq('barber_id', barberId)
        .eq('status', 'aktif') 
        .lt('jadwal', selesai.toUtc().toIso8601String())
        .gt('jadwal_selesai', mulai.toUtc().toIso8601String());
        
    if (excludeBookingId != null) query = query.neq('id', excludeBookingId);
    
    final response = await query;
    return response.isNotEmpty; 
  }

  Future<void> createBooking({
    required String nama, required String noHp, required DateTime jadwalMulai,
    required int? barberId, required List<Map<String, dynamic>> treatments, required int extraTime,
  }) async {
    int totalMenit = treatments.fold(0, (sum, t) => sum + (t['waktu_menit'] as int)) + extraTime;
    DateTime jadwalSelesai = jadwalMulai.add(Duration(minutes: totalMenit));

    if (await isOverlap(barberId, jadwalMulai, jadwalSelesai)) {
      throw Exception('Jadwal bertabrakan! Barber tersebut sudah melayani pelanggan lain pada jam itu.');
    }

    await _supabase.from('bookings').insert({
      'nama': nama, 'no_hp': noHp, 'sex': true,
      'status': 'aktif', 
      'jadwal': jadwalMulai.toUtc().toIso8601String(), 
      'jadwal_selesai': jadwalSelesai.toUtc().toIso8601String(), 
      'barber_id': barberId, 'extra_time': extraTime,
      'detail_treatments': jsonEncode(treatments),
    });
  }

  Future<void> updateBooking({
    required int bookingId, required String nama, required String noHp, required DateTime jadwalMulai,
    required int? barberId, required List<Map<String, dynamic>> treatments, required int extraTime,
  }) async {
    int totalMenit = treatments.fold(0, (sum, t) => sum + (t['waktu_menit'] as int)) + extraTime;
    DateTime jadwalSelesai = jadwalMulai.add(Duration(minutes: totalMenit));

    if (await isOverlap(barberId, jadwalMulai, jadwalSelesai, excludeBookingId: bookingId)) {
      throw Exception('Perubahan bertabrakan dengan jadwal Barber tersebut yang lain!');
    }

    await _supabase.from('bookings').update({
      'nama': nama, 'no_hp': noHp,
      'jadwal': jadwalMulai.toUtc().toIso8601String(), 
      'jadwal_selesai': jadwalSelesai.toUtc().toIso8601String(), 
      'barber_id': barberId, 'extra_time': extraTime,
      'detail_treatments': jsonEncode(treatments),
    }).eq('id', bookingId);
  }

  Future<void> cancelBooking(int bookingId) async {
    await _supabase.from('bookings').update({'status': 'batal'}).eq('id', bookingId);
  }

  // LOGIKA DIPANGKAS: Hanya menarik data, lalu diserahkan ke PdfService
  Future<void> generateBookingReport(DateTime start, DateTime end) async {
    try {
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      final startIso = start.toUtc().toIso8601String();
      final endIso = endOfDay.toUtc().toIso8601String();

      // 1. Tarik Data Base
      final data = await _supabase
          .from('bookings')
          .select('*, barbers(users(username))')
          .gte('jadwal', startIso)
          .lte('jadwal', endIso)
          .order('jadwal', ascending: true);

      // 2. Eksekusi desain PDF melalui Widget PdfService
      await PdfService.generateBookingReport(data: data, start: start, end: end);
      
    } catch (e) {
      throw Exception('Gagal membuat PDF Laporan Booking: $e');
    }
  }
}