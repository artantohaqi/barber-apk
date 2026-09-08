import 'package:flutter/material.dart';

// Cetakan untuk satu baris item di keranjang belanja
class CartItem {
  final int barberId;
  final String barberName;
  final int treatmentId;
  final String treatmentName;
  final int harga;
  final int komisi;
  int jumlah;

  CartItem({
    required this.barberId,
    required this.barberName,
    required this.treatmentId,
    required this.treatmentName,
    required this.harga,
    required this.komisi,
    this.jumlah = 1,
  });
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  // Menghitung total harga semua barang di keranjang
  int get grandTotalHarga {
    return _items.fold(0, (sum, item) => sum + (item.harga * item.jumlah));
  }

  // Fungsi menambah layanan ke keranjang
  void addItem(CartItem newItem) {
    // Cek apakah barber yang sama melakukan treatment yang sama
    int index = _items.indexWhere((i) => 
        i.barberId == newItem.barberId && i.treatmentId == newItem.treatmentId);
    
    if (index != -1) {
      // Jika sudah ada, tambahkan jumlahnya saja (misal pesen 2x cuci rambut)
      _items[index].jumlah += newItem.jumlah;
    } else {
      // Jika belum ada, masukkan sebagai baris baru
      _items.add(newItem);
    }
    // Wajib dipanggil agar layar UI langsung memuat ulang (refresh) otomatis
    notifyListeners();
  }

  // Fungsi menghapus item spesifik dari keranjang
  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  // Fungsi membersihkan keranjang setelah pembayaran sukses
  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}