import 'package:flutter/material.dart';
import '../services/report_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportService _reportService = ReportService();
  DateTimeRange _selectedRange = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  Map<String, dynamic>? _laporanData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLaporan();
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

  // FUNGSI BARU: POP-UP PILIHAN DOWNLOAD PDF
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
                  _reportService.generateReportPdf(_laporanData!, _selectedRange.start, _selectedRange.end, 'Pemasukan');
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_down, color: Colors.red),
                title: const Text('Hanya Pengeluaran'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _reportService.generateReportPdf(_laporanData!, _selectedRange.start, _selectedRange.end, 'Pengeluaran');
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance, color: Colors.blueGrey),
                title: const Text('Semua (Buku Kas)'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _reportService.generateReportPdf(_laporanData!, _selectedRange.start, _selectedRange.end, 'Semua');
                },
              ),
            ],
          ),
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
          // PASTIKAN BLOK ACTIONS INI ADA DI KODEMU
          actions: [
            if (_laporanData != null)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                tooltip: 'Download Laporan PDF',
                onPressed: _showDownloadDialog,
              )
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Ringkasan'), Tab(text: 'Pemasukan'), Tab(text: 'Pengeluaran')],
          ),
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
                      : TabBarView(
                          children: [
                            _buildTabRingkasan(),
                            _buildTabPemasukan(),
                            _buildTabPengeluaran(),
                          ],
                        ),
            )
          ],
        ),
      ),
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
          Text('Rp $amount', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTabPemasukan() {
    final List payments = _laporanData!['detail_pemasukan'];
    if (payments.isEmpty) return const Center(child: Text('Tidak ada pemasukan.'));
    
    return ListView.builder(
      itemCount: payments.length,
      itemBuilder: (context, i) {
        final p = payments[i];
        final List details = p['order_details'];
        final date = DateTime.parse(p['jadwal']).toLocal();
        return ExpansionTile(
          title: Text('${p['nama']} - Rp ${p['total_harga']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2,'0')}'),
          children: details.map((d) => ListTile(
            dense: true,
            title: Text(d['treatments']['treatment']),
            subtitle: Text('Barber: ${d['barbers']['users']['username']}'),
            trailing: Text('Rp ${d['jum_harga']} (x${d['jumlah']})'),
          )).toList(),
        );
      },
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
          trailing: Text('Rp ${e['harga']}', style: const TextStyle(color: Colors.red)),
        );
      },
    );
  }
}