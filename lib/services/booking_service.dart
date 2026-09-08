import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BookingService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getBookings() async {
    try {
      return await _supabase
          .from('bookings')
          .select('*, barbers(users(username))')
          .eq('status', 'aktif'); // HANYA TARIK YANG AKTIF
    } catch (e) {
      throw Exception('Gagal menarik data booking: $e');
    }
  }

  Future<bool> isOverlap(int? barberId, DateTime mulai, DateTime selesai, {int? excludeBookingId}) async {
    if (barberId == null) return false; 

    var query = _supabase.from('bookings')
        .select('id')
        .eq('barber_id', barberId)
        .eq('status', 'aktif') // HANYA CEK BENTROK DENGAN YANG AKTIF
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
      'status': 'aktif', // SET EXPLICIT KE AKTIF
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

  // FUNGSI BARU: MEMBATALKAN BOOKING (BUKAN MENGHAPUS)
  Future<void> cancelBooking(int bookingId) async {
    await _supabase.from('bookings').update({'status': 'batal'}).eq('id', bookingId);
  }

  Future<void> generateBookingReport(DateTime start, DateTime end) async {
    try {
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      final startIso = start.toUtc().toIso8601String();
      final endIso = endOfDay.toUtc().toIso8601String();

      final data = await _supabase
          .from('bookings')
          .select('*, barbers(users(username))')
          .gte('jadwal', startIso)
          .lte('jadwal', endIso)
          .order('jadwal', ascending: true);

      final pdf = pw.Document();
      final dateStr = '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Center(child: pw.Text('LAPORAN JADWAL BOOKING', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Bintangss Barbershop', style: const pw.TextStyle(fontSize: 12))),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Periode: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
              pw.SizedBox(height: 24),
              
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headerHeight: 25,
                cellHeight: 25,
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                cellAlignments: {
                  0: pw.Alignment.center, 1: pw.Alignment.center, 2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft, 4: pw.Alignment.centerLeft, 5: pw.Alignment.center,
                },
                headers: ['No', 'Tanggal', 'Jam', 'Pelanggan', 'Barber', 'Status'],
                data: List<List<String>>.generate(
                  data.length,
                  (index) {
                    final b = data[index];
                    final jadwal = DateTime.parse(b['jadwal']).toLocal();
                    final tgl = '${jadwal.day.toString().padLeft(2, '0')}/${jadwal.month.toString().padLeft(2, '0')}/${jadwal.year}';
                    final jam = '${jadwal.hour.toString().padLeft(2, '0')}:${jadwal.minute.toString().padLeft(2, '0')}';
                    final nama = b['nama'] ?? '-';
                    final barber = b['barbers'] != null ? b['barbers']['users']['username'] : 'Bebas';
                    
                    // FORMAT STATUS HURUF KAPITAL (Aktif, Selesai, Batal)
                    String status = b['status']?.toString() ?? 'Aktif';
                    status = status.substring(0, 1).toUpperCase() + status.substring(1).toLowerCase();

                    return [(index + 1).toString(), tgl, jam, nama, barber, status];
                  },
                ),
              ),
            ];
          },
        ),
      );

      final now = DateTime.now();
      final String fileName = 'Laporan_Booking_${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: fileName, // Menerapkan nama file yang baru
      );
    } catch (e) {
      throw Exception('Gagal membuat PDF Laporan Booking: $e');
    }
  }
}