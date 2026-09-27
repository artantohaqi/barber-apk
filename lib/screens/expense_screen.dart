import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // TAMBAHAN: Untuk format titik ribuan
import '../services/expense_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final ExpenseService _expenseService = ExpenseService();
  late Future<List<Map<String, dynamic>>> _expensesFuture;
  
  // INISIALISASI FORMATTER RUPIAH
  final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _expensesFuture = _expenseService.getExpenses();
    });
  }

  // FUNGSI BARU: Dialog gabungan untuk Tambah & Edit
  void _showFormDialog({Map<String, dynamic>? existingExpense}) {
    final isEdit = existingExpense != null;
    final kategoriCtrl = TextEditingController(text: isEdit ? existingExpense['kategori'] : '');
    final hargaCtrl = TextEditingController(text: isEdit ? existingExpense['harga'].toString() : '');
    final keteranganCtrl = TextEditingController(text: isEdit ? existingExpense['keterangan'] : '');
    
    // Inisialisasi tanggal: pakai tanggal lama jika mode Edit, pakai hari ini jika mode Tambah
    DateTime selectedDate = isEdit ? DateTime.parse(existingExpense['tanggal']).toLocal() : DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) { 
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Pengeluaran' : 'Catat Pengeluaran'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TOMBOL PILIH TANGGAL
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal Pengeluaran', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_month, color: Colors.blueGrey),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        // Gabungkan dengan jam saat ini agar tidak tumpang tindih urutan waktunya
                        final now = DateTime.now();
                        setDialogState(() {
                          selectedDate = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute, now.second);
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: kategoriCtrl,
                    decoration: const InputDecoration(labelText: 'Kategori (Misal: Listrik, Air, Gaji)'),
                  ),
                  TextField(
                    controller: hargaCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Nominal (Rp)', prefixText: 'Rp '),
                  ),
                  TextField(
                    controller: keteranganCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Keterangan Tambahan (Opsional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (kategoriCtrl.text.isEmpty || hargaCtrl.text.isEmpty) return;

                        setDialogState(() => isSaving = true);
                        try {
                          if (isEdit) {
                            await _expenseService.editExpense(
                              existingExpense['id'],
                              kategoriCtrl.text.trim(),
                              int.parse(hargaCtrl.text.trim()),
                              keteranganCtrl.text.trim(),
                              selectedDate,
                            );
                          } else {
                            await _expenseService.addExpense(
                              kategoriCtrl.text.trim(),
                              int.parse(hargaCtrl.text.trim()),
                              keteranganCtrl.text.trim(),
                              selectedDate,
                            );
                          }
                          
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          _refreshData();
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
              ),
            ],
          );
        });
      },
    );
  }

  // FUNGSI BARU: Konfirmasi penghapusan data
  void _deleteExpense(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data?'),
        content: const Text('Pengeluaran ini akan dihapus secara permanen dari laporan keuangan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Hapus')
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await _expenseService.deleteExpense(id);
        _refreshData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pencatatan Pengeluaran')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Belum ada data pengeluaran.'));

          final expenses = snapshot.data!;
          return ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final item = expenses[index];
              final tanggal = DateTime.parse(item['tanggal']).toLocal();
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.money_off, color: Colors.white),
                  ),
                  title: Text(item['kategori'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${tanggal.day}/${tanggal.month}/${tanggal.year} | ${item['keterangan']}'),
                  // PERBAIKAN TRAILING: Memuat Harga (Dengan format Rp), Tombol Edit, dan Tombol Hapus
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatRp.format(item['harga']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                        onPressed: () => _showFormDialog(existingExpense: item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteExpense(item['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(), // Panggil fungsi gabungan tanpa parameter (mode Tambah)
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}