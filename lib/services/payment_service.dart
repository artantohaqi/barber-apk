import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/cart_provider.dart';

class PaymentService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getActiveViaPayments() async {
    return await _supabase.from('via_payments').select().eq('is_active', true);
  }

  Future<void> prosesPembayaran({
    required CartProvider cart,
    required int viaPaymentId,
    required String namaCustomer,
    required String noHp,
    int? bookingId, // Parameter baru untuk mendeteksi asal transaksi
  }) async {
    try {
      String timestamp = DateTime.now().toIso8601String();
      // Format nomor pesanan disesuaikan dengan contoh gambarmu
      String namaNota = 'TRX-${DateTime.now().millisecondsSinceEpoch}'; 

      // 1. Simpan ke tabel Payments & ambil ID
      final paymentResponse = await _supabase.from('payments').insert({
        'nama': namaCustomer.isEmpty ? 'Walk-in' : namaCustomer,
        'no_hp': noHp.isEmpty ? '-' : noHp,
        'sex': true, 
        'jadwal': timestamp,
        'via_id': viaPaymentId,
        'total_harga': cart.grandTotalHarga,
        'nama_nota': '$namaNota.pdf',
      }).select('id').single();

      int newPaymentId = paymentResponse['id'];

      // 2. Siapkan data batch order_details
      List<Map<String, dynamic>> orderDetails = cart.items.map((item) => {
        'barber_id': item.barberId,
        'payment_id': newPaymentId,
        'treatment_id': item.treatmentId,
        'jumlah': item.jumlah,
        'jum_harga': item.harga * item.jumlah,
        'jum_komisi': item.komisi * item.jumlah,
      }).toList();

      // 3. Tembakkan isi keranjang
      await _supabase.from('order_details').insert(orderDetails);

      // 4. Jika transaksi ini berasal dari Kalender Booking, selesaikan jadwalnya
      if (bookingId != null) {
        await _supabase.from('bookings').update({'status': 'selesai'}).eq('id', bookingId);
      }

      // 5. Cetak PDF dengan desain rapi
      await _generatePdfDialog(cart, namaNota, namaCustomer, cart.grandTotalHarga);

      // 6. Bersihkan keranjang
      cart.clearCart();

    } catch (e) {
      throw Exception('Gagal memproses pembayaran: $e');
    }
  }

  Future<void> _generatePdfDialog(CartProvider cart, String namaNota, String namaCustomer, int total) async {
    final pdf = pw.Document();
    
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final tglString = '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year.toString().substring(2)} (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})';

    // Memaksa ukuran TEPAT 8 cm (80mm) x 10.5 cm (105mm)
    final customFormat = PdfPageFormat(80 * PdfPageFormat.mm, 105 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: customFormat, 
        build: (pw.Context context) {
          const double fSize = 9; 
          const double fTitle = 14;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('bintangss barbershop', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fTitle))),
              pw.Center(child: pw.Text('nomor_kontak', style: const pw.TextStyle(fontSize: fSize))),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // pw.Text('No. Order : $namaNota', style: const pw.TextStyle(fontSize: fSize)),
              if (namaCustomer.isNotEmpty) pw.Text('Pelanggan : $namaCustomer', style: const pw.TextStyle(fontSize: fSize)),
              pw.Text('Tanggal : $tglString', style: const pw.TextStyle(fontSize: fSize)),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // DAFTAR ITEM (MENAMPILKAN NAMA BARBER)
              pw.Expanded(
                child: pw.ListView(
                  children: cart.items.map((item) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Nama Treatment dibuat bold agar membedakan dengan nama Barber
                      pw.Text(item.treatmentName, style: pw.TextStyle(fontSize: fSize, fontWeight: pw.FontWeight.bold)),
                      
                      // Menampilkan nama Barber (Ukuran sedikit lebih kecil dan warna abu-abu gelap)
                      pw.Text('Barber: ${item.barberName}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.SizedBox(width: 10), 
                          pw.Text('${item.jumlah} x Rp${item.harga}', style: const pw.TextStyle(fontSize: fSize)),
                          pw.Text('Rp${item.harga * item.jumlah}', style: const pw.TextStyle(fontSize: fSize)),
                        ]
                      ),
                      pw.SizedBox(height: 4), // Spasi antar item
                    ]
                  )).toList(),
                )
              ),

              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sub Total', style: const pw.TextStyle(fontSize: fSize)),
                  pw.Text('Rp$total', style: const pw.TextStyle(fontSize: fSize)),
                ]
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text('Rp$total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('Terima Kasih', style: const pw.TextStyle(fontSize: fSize, color: PdfColors.grey600))),
            ],
          );
        },
      ),
    );

    final String fileName = 'Nota_${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName, // Menerapkan nama file yang baru
    );
  }
}