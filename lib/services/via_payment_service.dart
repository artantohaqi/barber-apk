import 'package:supabase_flutter/supabase_flutter.dart';

class ViaPaymentService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getViaPayments() async {
    return await _supabase.from('via_payments').select().order('id', ascending: true);
  }

  Future<void> addViaPayment(String via) async {
    await _supabase.from('via_payments').insert({'via': via});
  }

  Future<void> updateViaPayment(int id, String via, bool isActive) async {
    await _supabase.from('via_payments').update({'via': via, 'is_active': isActive}).eq('id', id);
  }
}