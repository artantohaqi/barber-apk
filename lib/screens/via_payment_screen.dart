import 'package:flutter/material.dart';
import '../services/via_payment_service.dart';

class ViaPaymentScreen extends StatefulWidget {
  const ViaPaymentScreen({super.key});

  @override
  State<ViaPaymentScreen> createState() => _ViaPaymentScreenState();
}

class _ViaPaymentScreenState extends State<ViaPaymentScreen> {
  final _service = ViaPaymentService();
  late Future<List<Map<String, dynamic>>> _futureData;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _futureData = _service.getViaPayments();
    });
  }

  void _showForm({Map<String, dynamic>? item}) {
    final viaCtrl = TextEditingController(text: item != null ? item['via'] : '');
    bool isActive = item != null ? item['is_active'] : true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Tambah Pembayaran' : 'Edit Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: viaCtrl, decoration: const InputDecoration(labelText: 'Nama (Misal: BCA, QRIS)')),
              if (item != null) SwitchListTile(
                title: const Text('Aktif'),
                value: isActive,
                onChanged: (val) => setDialogState(() => isActive = val),
              )
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (viaCtrl.text.isEmpty) return;
                item == null 
                  ? await _service.addViaPayment(viaCtrl.text.trim())
                  : await _service.updateViaPayment(item['id'], viaCtrl.text.trim(), isActive);
                if (!context.mounted) return;
                Navigator.pop(context);
                _refresh();
              },
              child: const Text('Simpan'),
            )
          ],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metode Pembayaran')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(data[i]['via']),
              subtitle: Text(data[i]['is_active'] ? 'Aktif' : 'Tidak Aktif'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(item: data[i])),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add)),
    );
  }
}