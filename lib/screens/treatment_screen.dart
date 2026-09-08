import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/treatment_service.dart';

class TreatmentScreen extends StatefulWidget {
  const TreatmentScreen({super.key});

  @override
  State<TreatmentScreen> createState() => _TreatmentScreenState();
}

class _TreatmentScreenState extends State<TreatmentScreen> {
  final TreatmentService _treatmentService = TreatmentService();
  late Future<List<Map<String, dynamic>>> _treatmentsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _treatmentsFuture = _treatmentService.getTreatments();
    });
  }

  // Dialog yang berfungsi ganda: Add & Edit
  void _showFormDialog({Map<String, dynamic>? existingTreatment}) {
    final bool isEdit = existingTreatment != null;
    
    final namaCtrl = TextEditingController(text: isEdit ? existingTreatment['treatment'] : '');
    final waktuCtrl = TextEditingController(text: isEdit ? existingTreatment['waktu_menit'].toString() : '');
    final hargaCtrl = TextEditingController(text: isEdit ? existingTreatment['harga'].toString() : '');
    final komisiCtrl = TextEditingController(text: isEdit ? existingTreatment['komisi'].toString() : '');
    bool isActive = isEdit ? existingTreatment['is_active'] : true;
    
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Layanan' : 'Tambah Layanan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Layanan (Contoh: Haircut)'),
                  ),
                  TextField(
                    controller: waktuCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Estimasi Waktu (Menit)', suffixText: 'Menit'),
                  ),
                  TextField(
                    controller: hargaCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Harga Jual (Rp)', prefixText: 'Rp '),
                  ),
                  TextField(
                    controller: komisiCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Komisi Barber (Rp)', prefixText: 'Rp '),
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Status Aktif'),
                      subtitle: Text(isActive ? 'Muncul di Kasir' : 'Disembunyikan (Soft Delete)'),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (namaCtrl.text.isEmpty || waktuCtrl.text.isEmpty || hargaCtrl.text.isEmpty || komisiCtrl.text.isEmpty) {
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          final nama = namaCtrl.text.trim();
                          final waktu = int.parse(waktuCtrl.text.trim());
                          final harga = int.parse(hargaCtrl.text.trim());
                          final komisi = int.parse(komisiCtrl.text.trim());

                          if (isEdit) {
                            await _treatmentService.updateTreatment(existingTreatment['id'], nama, waktu, harga, komisi, isActive);
                          } else {
                            await _treatmentService.addTreatment(nama, waktu, harga, komisi);
                          }

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _refreshData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEdit ? 'Berhasil mengedit layanan!' : 'Berhasil menambah layanan!')),
                          );
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      appBar: AppBar(title: const Text('Layanan & Harga')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _treatmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada data layanan.'));
          }

          final treatments = snapshot.data!;
          return ListView.builder(
            itemCount: treatments.length,
            itemBuilder: (context, index) {
              final item = treatments[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item['is_active'] ? Colors.green : Colors.red,
                    child: const Icon(Icons.cut, color: Colors.white, size: 20),
                  ),
                  title: Text(item['treatment'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Rp ${item['harga']} | Komisi: Rp ${item['komisi']} | Waktu: ${item['waktu_menit']} mnt'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueGrey),
                    onPressed: () => _showFormDialog(existingTreatment: item),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}