import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/report_service.dart';
import '../services/pos_service.dart'; 
import '../services/payment_service.dart'; 
import '../widgets/pdf_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportService _reportService = ReportService();
  final PosService _posService = PosService();
  final PaymentService _paymentService = PaymentService();
  
  DateTimeRange _selectedRange = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  Map<String, dynamic>? _laporanData;
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _activeBarbers = [];
  List<Map<String, dynamic>> _activeTreatments = [];
  List<Map<String, dynamic>> _viaPayments = [];
  int? _selectedBarberFilter;

  final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchLaporan();
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    final barbers = await _posService.getActiveBarbers();
    final treatments = await _posService.getActiveTreatments();
    final vias = await _paymentService.getActiveViaPayments();
    if (mounted) {
      setState(() {
        _activeBarbers = barbers;
        _activeTreatments = treatments;
        _viaPayments = vias;
      });
    }
  }

  Future<void> _fetchLaporan() async {
    setState(() => _isLoading = true);
    try {
      final data = await _reportService.getLaporan(_selectedRange.start, _selectedRange.end);
      if (!mounted) return;
      setState(() => _laporanData = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pilihTanggal() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDateRange: _selectedRange,
    );
    if (picked != null && picked != _selectedRange) {
      setState(() => _selectedRange = picked);
      _fetchLaporan();
    }
  }

  void _downloadNotaUlang(Map<String, dynamic> payment) {
    List details = payment['order_details'];
    List<Map<String, dynamic>> pdfItems = details.map((d) => {
      'treatmentName': d['treatments']['treatment'],
      'barberName': d['barbers']['users']['username'],
      'jumlah': d['jumlah'],
      'harga': (d['jum_harga'] / d['jumlah']).round(),
    }).toList();

    PdfService.generateNota(
      namaNota: payment['nama_nota'] ?? 'TRX-RePrint.pdf',
      namaCustomer: payment['nama'] ?? '-',
      totalHarga: payment['total_harga'],
      tanggal: DateTime.parse(payment['jadwal']).toLocal(),
      items: pdfItems,
    );
  }

  // --- FUNGSI BARU (DIKEMBALIKAN): Dialog Download Laporan PDF ---
  void _showDownloadDialog() {
    if (_laporanData == null) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pilih Jenis Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.green),
                title: const Text('Hanya Pemasukan'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  PdfService.generateLaporan(data: _laporanData!, start: _selectedRange.start, end: _selectedRange.end, type: 'Pemasukan');
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_down, color: Colors.red),
                title: const Text('Hanya Pengeluaran'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  PdfService.generateLaporan(data: _laporanData!, start: _selectedRange.start, end: _selectedRange.end, type: 'Pengeluaran');
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance, color: Colors.blueGrey),
                title: const Text('Semua (Buku Kas)'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  PdfService.generateLaporan(data: _laporanData!, start: _selectedRange.start, end: _selectedRange.end, type: 'Semua');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditHeaderDialog(Map<String, dynamic> payment) {
    final namaCtrl = TextEditingController(text: payment['nama'] == 'Walk-in' ? '' : payment['nama']);
    DateTime selectedDateTime = DateTime.parse(payment['jadwal']).toLocal();
    int selectedViaId = payment['via_id'] ?? (_viaPayments.isNotEmpty ? _viaPayments[0]['id'] : null);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final tglStr = '${selectedDateTime.day}/${selectedDateTime.month}/${selectedDateTime.year}';
          final jamStr = '${selectedDateTime.hour.toString().padLeft(2,'0')}:${selectedDateTime.minute.toString().padLeft(2,'0')}';

          return AlertDialog(
            title: const Text('Edit Info Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Pelanggan (Kosong = Walk-in)'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ubah Tanggal & Jam', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text('$tglStr, Jam $jamStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.edit_calendar, color: Colors.blueGrey),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context, 
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime)
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            selectedDateTime = DateTime(
                              pickedDate.year, pickedDate.month, pickedDate.day, 
                              pickedTime.hour, pickedTime.minute
                            );
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_viaPayments.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: _viaPayments.any((v) => v['id'] == selectedViaId) ? selectedViaId : _viaPayments[0]['id'],
                      decoration: const InputDecoration(labelText: 'Metode Pembayaran'),
                      items: _viaPayments.map((v) => DropdownMenuItem<int>(value: v['id'], child: Text(v['via']))).toList(),
                      onChanged: (val) { if (val != null) setDialogState(() => selectedViaId = val); },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(dialogCtx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  setDialogState(() => isSaving = true);
                  try {
                    await _reportService.updateTransactionHeader(
                      payment['id'], 
                      namaCtrl.text.trim().isEmpty ? 'Walk-in' : namaCtrl.text.trim(), 
                      selectedDateTime, 
                      selectedViaId
                    );
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);
                    _fetchLaporan();
                  } catch (e) {
                    setDialogState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: isSaving ? const CircularProgressIndicator() : const Text('Simpan'),
              ),
            ],
          );
        });
      },
    );
  }

  void _deleteTransactionFull(int paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Seluruh layanan, nota, dan catatan pembayaran ini akan dihapus permanen.'),
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
        await _reportService.deleteTransaction(paymentId);
        _fetchLaporan();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showItemDialog({required int paymentId, Map<String, dynamic>? detail}) {
    final isEdit = detail != null;
    int selectedBarberId = isEdit ? detail['barber_id'] : (_activeBarbers.isNotEmpty ? _activeBarbers[0]['id'] : 0);
    Map<String, dynamic> selectedTreatment = isEdit 
        ? _activeTreatments.firstWhere((t) => t['id'] == detail['treatment_id']) 
        : (_activeTreatments.isNotEmpty ? _activeTreatments[0] : {});
    
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Layanan' : 'Tambah Layanan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: _activeBarbers.any((b) => b['id'] == selectedBarberId) ? selectedBarberId : null,
                  decoration: const InputDecoration(labelText: 'Barber yang melayani'),
                  items: _activeBarbers.map((b) => DropdownMenuItem<int>(value: b['id'], child: Text(b['users']['username']))).toList(),
                  onChanged: (val) { if (val != null) setDialogState(() => selectedBarberId = val); },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _activeTreatments.contains(selectedTreatment) ? selectedTreatment : null,
                  decoration: const InputDecoration(labelText: 'Jenis Layanan'),
                  items: _activeTreatments.map((t) => DropdownMenuItem(value: t, child: Text('${t['treatment']} (${formatRp.format(t['harga'])})'))).toList(),
                  onChanged: (val) { if (val != null) setDialogState(() => selectedTreatment = val); },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(dialogCtx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  setDialogState(() => isSaving = true);
                  try {
                    if (isEdit) {
                      await _reportService.editTransactionItem(
                        paymentId: paymentId,
                        orderDetailId: detail['id'],
                        newBarberId: selectedBarberId,
                        newTreatment: selectedTreatment,
                        jumlah: detail['jumlah'],
                      );
                    } else {
                      await _reportService.addTransactionItem(
                        paymentId: paymentId,
                        barberId: selectedBarberId,
                        treatment: selectedTreatment,
                        jumlah: 1, 
                      );
                    }
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);
                    _fetchLaporan();
                  } catch (e) {
                    setDialogState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: isSaving ? const CircularProgressIndicator() : const Text('Simpan'),
              ),
            ],
          );
        });
      },
    );
  }

  void _deleteItem(int paymentId, int detailId, int detailCount) async {
    if (detailCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak bisa menghapus layanan terakhir. Hapus transaksinya secara langsung!')));
      return;
    }
    
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Layanan?'),
          content: const Text('Layanan ini akan dihapus dari tagihan nota.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
          ],
        )
      );

      if (confirm == true) {
        try {
          await _reportService.deleteTransactionItem(paymentId, detailId);
          _fetchLaporan();
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
  }

  Widget _buildTabPemasukan() {
    List payments = _laporanData!['detail_pemasukan'];
    int totalKomisiBarber = 0, totalTransaksiBarber = 0;

    if (_selectedBarberFilter != null) {
      payments = payments.where((p) {
        List details = p['order_details'];
        bool hasBarber = details.any((d) => d['barbers']['id'] == _selectedBarberFilter);
        if (hasBarber) {
          totalTransaksiBarber++;
          for (var d in details) {
            if (d['barbers']['id'] == _selectedBarberFilter) totalKomisiBarber += (d['jum_komisi'] as int);
          }
        }
        return hasBarber;
      }).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.filter_alt, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  hint: const Text('Semua Barber'),
                  value: _selectedBarberFilter,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Tampilkan Semua Transaksi')),
                    ..._activeBarbers.map((b) => DropdownMenuItem<int>(value: b['id'], child: Text(b['users']['username'])))
                  ],
                  onChanged: (val) => setState(() => _selectedBarberFilter = val),
                ),
              ),
            ],
          ),
        ),
        if (_selectedBarberFilter != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Komisi Barber:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text('$totalTransaksiBarber Transaksi ditemukan', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                Text(formatRp.format(totalKomisiBarber), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
        Expanded(
          child: payments.isEmpty 
            ? const Center(child: Text('Tidak ada transaksi.'))
            : ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, i) {
                  final p = payments[i];
                  final List details = p['order_details'];
                  final date = DateTime.parse(p['jadwal']).toLocal();

                  String viaName = p['via_payments'] != null ? p['via_payments']['via'] : '-';
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Expanded(child: Text('${p['nama']} - ${formatRp.format(p['total_harga'])}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2,'0')}'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  border: Border.all(color: Colors.green),
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text('Via: $viaName', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Nota: ${p['nama_nota'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.print, color: Colors.blue, size: 20), onPressed: () => _downloadNotaUlang(p)),
                          IconButton(icon: const Icon(Icons.edit_document, color: Colors.orange, size: 20), onPressed: () => _showEditHeaderDialog(p)),
                          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20), onPressed: () => _deleteTransactionFull(p['id'])),
                        ],
                      ),
                      children: [
                        ...details.map((d) => ListTile(
                          dense: true,
                          title: Text(d['treatments']['treatment']),
                          subtitle: Text('Barber: ${d['barbers']['users']['username']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${formatRp.format(d['jum_harga'])} (x${d['jumlah']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.orange), onPressed: () => _showItemDialog(paymentId: p['id'], detail: d)),
                              IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _deleteItem(p['id'], d['id'], details.length)),
                            ],
                          ),
                        )),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Tambah Layanan'),
                            onPressed: () => _showItemDialog(paymentId: p['id']),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildTabRingkasan() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReportCard('Pemasukan (Kotor)', _laporanData!['pemasukan'], Colors.green),
        const SizedBox(height: 16),
        _buildReportCard('Total Pengeluaran', _laporanData!['pengeluaran'], Colors.red),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 2)),
        _buildReportCard('Laba Bersih', _laporanData!['laba_bersih'], Colors.blueGrey, isBold: true),
      ],
    );
  }

  Widget _buildReportCard(String title, int amount, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(height: 8),
          Text(formatRp.format(amount), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTabPengeluaran() {
    final List expenses = _laporanData!['detail_pengeluaran'];
    if (expenses.isEmpty) return const Center(child: Text('Tidak ada pengeluaran.'));
    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (context, i) {
        final e = expenses[i];
        final date = DateTime.parse(e['tanggal']).toLocal();
        return ListTile(
          title: Text(e['kategori'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${date.day}/${date.month} | ${e['keterangan']}'),
          trailing: Text(formatRp.format(e['harga']), style: const TextStyle(color: Colors.red)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan Keuangan'),
          // --- PERBAIKAN: Tombol Download Laporan PDF Dikembalikan di Sini ---
          actions: [
            if (_laporanData != null)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                tooltip: 'Download Laporan PDF',
                onPressed: _showDownloadDialog,
              )
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Ringkasan'), Tab(text: 'Pemasukan'), Tab(text: 'Pengeluaran')]),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: _pilihTanggal,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.date_range),
                      Text('${_selectedRange.start.day}/${_selectedRange.start.month}/${_selectedRange.start.year} - ${_selectedRange.end.day}/${_selectedRange.end.month}/${_selectedRange.end.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _laporanData == null
                      ? const SizedBox()
                      : TabBarView(children: [_buildTabRingkasan(), _buildTabPemasukan(), _buildTabPengeluaran()]),
            )
          ],
        ),
      ),
    );
  }
}