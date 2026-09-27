import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../services/payment_service.dart';

class CheckoutScreen extends StatefulWidget {
  final String? initialNama;
  final String? initialNoHp;
  final int? bookingId; 

  const CheckoutScreen({super.key, this.initialNama, this.initialNoHp, this.bookingId});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final PaymentService _paymentService = PaymentService();
  
  late final TextEditingController _namaCtrl;
  late final TextEditingController _noHpCtrl;
  
  List<Map<String, dynamic>> _viaPayments = [];
  int? _selectedViaId;
  
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.initialNama ?? '');
    _noHpCtrl = TextEditingController(text: widget.initialNoHp ?? '');
    _loadViaPayments();
  }
  
  Future<void> _loadViaPayments() async {
    try {
      final data = await _paymentService.getActiveViaPayments();
      if (!mounted) return;
      setState(() {
        _viaPayments = data;
        if (data.isNotEmpty) _selectedViaId = data[0]['id']; 
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _prosesBayar() async {
    if (_selectedViaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih metode pembayaran!')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      
      await _paymentService.prosesPembayaran(
        cart: cart,
        viaPaymentId: _selectedViaId!,
        namaCustomer: _namaCtrl.text.trim(),
        noHp: _noHpCtrl.text.trim(),
        bookingId: widget.bookingId, 
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembayaran Berhasil!')));
      Navigator.pop(context); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // FORMATTER RUPIAH DENGAN PEMISAH TITIK RIBUAN
    final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Penyelesaian Transaksi')),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return const Center(child: Text('Keranjang Kosong.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      const Text('TOTAL TAGIHAN', style: TextStyle(color: Colors.white, fontSize: 16)),
                      // PENERAPAN FORMAT RUPIAH PADA TOTAL TAGIHAN
                      Text(
                        formatRp.format(cart.grandTotalHarga), 
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Data Pelanggan (Opsional):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _namaCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Pelanggan', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noHpCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nomor HP', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                const Text('Metode Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedViaId,
                      isDense: true,
                      items: _viaPayments.map((via) => DropdownMenuItem<int>(value: via['id'], child: Text(via['via']))).toList(),
                      onChanged: (val) => setState(() => _selectedViaId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: _isProcessing ? null : _prosesBayar,
                    child: _isProcessing 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SELESAIKAN PEMBAYARAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}