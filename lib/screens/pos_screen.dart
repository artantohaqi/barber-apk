import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/pos_service.dart';
import 'checkout_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final PosService _posService = PosService();
  
  List<Map<String, dynamic>> _barbers = [];
  List<Map<String, dynamic>> _treatments = [];
  
  Map<String, dynamic>? _selectedBarber;
  // Menggunakan List untuk menampung banyak treatment yang dicentang
  final List<Map<String, dynamic>> _checkedTreatments = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final barbers = await _posService.getActiveBarbers();
      final treatments = await _posService.getActiveTreatments();
      
      if (!mounted) return;
      setState(() {
        _barbers = barbers;
        _treatments = treatments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _addToCart() {
    if (_selectedBarber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Barber terlebih dahulu!')));
      return;
    }
    
    if (_checkedTreatments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Centang minimal satu layanan!')));
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    // Looping semua layanan yang dicentang dan masukkan ke RAM
    for (var treatment in _checkedTreatments) {
      cartProvider.addItem(CartItem(
        barberId: _selectedBarber!['id'],
        barberName: _selectedBarber!['users']['username'],
        treatmentId: treatment['id'],
        treatmentName: treatment['treatment'],
        harga: treatment['harga'],
        komisi: treatment['komisi'],
      ));
    }

    // Bersihkan centangan setelah berhasil ditambahkan ke keranjang
    setState(() {
      _checkedTreatments.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Kasir (Pilih Layanan)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- BAGIAN 1: INPUT BARBER & CHECKBOX LAYANAN ---
            InputDecorator(
              decoration: const InputDecoration(labelText: '1. Pilih Barber', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedBarber,
                  isDense: true,
                  hint: const Text('Siapa yang memotong?'),
                  items: _barbers.map((barber) => DropdownMenuItem(value: barber, child: Text(barber['users']['username']))).toList(),
                  onChanged: (val) => setState(() => _selectedBarber = val),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Area Checkbox yang bisa di-scroll jika layanan sangat banyak
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('2. Pilih Layanan (Bisa lebih dari satu):', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Container(
              height: 140, // Membatasi tinggi agar tidak menelan daftar keranjang di bawahnya
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _treatments.length,
                itemBuilder: (context, index) {
                  final t = _treatments[index];
                  final isChecked = _checkedTreatments.contains(t);
                  
                  return CheckboxListTile(
                    title: Text(t['treatment'], style: const TextStyle(fontSize: 14)),
                    subtitle: Text('Rp${t['harga']}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                    value: isChecked,
                    dense: true,
                    activeColor: Colors.blueGrey,
                    onChanged: (bool? val) {
                      setState(() {
                        if (val == true) {
                          _checkedTreatments.add(t);
                        } else {
                          _checkedTreatments.remove(t);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('TAMBAHKAN KE TAGIHAN'),
              ),
            ),
            const Divider(height: 32, thickness: 2),

            // --- BAGIAN 2: DAFTAR KERANJANG (REAL-TIME) ---
            const Align(
              alignment: Alignment.centerLeft, 
              child: Text('3. Daftar Tagihan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Consumer<CartProvider>(
                builder: (context, cart, child) {
                  if (cart.items.isEmpty) {
                    return const Center(child: Text('Belum ada layanan yang ditambahkan', style: TextStyle(color: Colors.grey)));
                  }
                  
                  return ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.treatmentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Barber: ${item.barberName} | Harga: Rp${item.harga} x ${item.jumlah}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => cart.removeItem(index),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // --- BAGIAN 3: TOTAL & LANJUT BAYAR ---
            Consumer<CartProvider>(
              builder: (context, cart, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Harga', style: TextStyle(fontSize: 14)),
                          Text(
                            'Rp ${cart.grandTotalHarga}', 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey)
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: cart.items.isEmpty ? null : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                          );
                        },
                        child: const Text('LANJUT BAYAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}