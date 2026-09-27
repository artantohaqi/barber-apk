import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';
import '../widgets/pdf_service.dart'; // Import pabrik PDF kita

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
    int? bookingId,
  }) async {
    try {
      final now = DateTime.now();
      String timestamp = now.toUtc().toIso8601String(); 
      String namaNotaLengkap = 'TRX-${now.millisecondsSinceEpoch}.pdf';

      final paymentResponse = await _supabase.from('payments').insert({
        'nama': namaCustomer.isEmpty ? 'Walk-in' : namaCustomer,
        'no_hp': noHp.isEmpty ? '-' : noHp,
        'sex': true, 
        'jadwal': timestamp,
        'via_id': viaPaymentId,
        'total_harga': cart.grandTotalHarga,
        'nama_nota': namaNotaLengkap, 
      }).select('id').single();

      int newPaymentId = paymentResponse['id'];

      List<Map<String, dynamic>> orderDetails = cart.items.map((item) => {
        'barber_id': item.barberId,
        'payment_id': newPaymentId,
        'treatment_id': item.treatmentId,
        'jumlah': item.jumlah,
        'jum_harga': item.harga * item.jumlah,
        'jum_komisi': item.komisi * item.jumlah,
      }).toList();

      await _supabase.from('order_details').insert(orderDetails);

      if (bookingId != null) {
        await _supabase.from('bookings').update({'status': 'selesai'}).eq('id', bookingId);
      }

      // 5. PANGGIL PABRIK PDF DARI WIDGET
      List<Map<String, dynamic>> pdfItems = cart.items.map((i) => {
        'treatmentName': i.treatmentName,
        'barberName': i.barberName,
        'jumlah': i.jumlah,
        'harga': i.harga,
      }).toList();

      await PdfService.generateNota(
        namaNota: namaNotaLengkap,
        namaCustomer: namaCustomer,
        totalHarga: cart.grandTotalHarga,
        tanggal: now,
        items: pdfItems,
      );

      cart.clearCart();
    } catch (e) {
      throw Exception('Gagal memproses pembayaran: $e');
    }
  }
}