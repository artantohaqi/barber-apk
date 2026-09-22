import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/expense_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final ExpenseService _expenseService = ExpenseService();
  late Future<List<Map<String, dynamic>>> _expensesFuture;

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

  void _showAddDialog() {
    final kategoriCtrl = TextEditingController();
    final hargaCtrl = TextEditingController();
    final keteranganCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) { // PERBAIKAN: Pisahkan penamaan konteks dialog
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Catat Pengeluaran'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext), // PERBAIKAN: Gunakan dialogContext
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (kategoriCtrl.text.isEmpty || hargaCtrl.text.isEmpty) return;

                        setDialogState(() => isSaving = true);
                        try {
                          await _expenseService.addExpense(
                            kategoriCtrl.text.trim(),
                            int.parse(hargaCtrl.text.trim()),
                            keteranganCtrl.text.trim(),
                          );
                          if (!dialogContext.mounted) return; // PERBAIKAN: Periksa dialogContext untuk mencegah Async Gap
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
                  trailing: Text('Rp ${item['harga']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}