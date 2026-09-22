import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getLaporan(DateTime start, DateTime end) async {
    try {
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      final startIso = start.toUtc().toIso8601String();
      final endIso = endOfDay.toUtc().toIso8601String();

      // Menarik rincian Pemasukan beserta relasinya
      final payments = await _supabase
          .from('payments')
          .select('id, nama, total_harga, jadwal, order_details(jumlah, jum_harga, treatments(treatment), barbers(users(username)))')
          .gte('jadwal', startIso)
          .lte('jadwal', endIso)
          .order('jadwal', ascending: false);

      int totalPemasukan = payments.fold(0, (sum, item) => sum + (item['total_harga'] as int));

      // Menarik rincian Pengeluaran
      final expenses = await _supabase
          .from('expenses')
          .select('*')
          .gte('tanggal', startIso)
          .lte('tanggal', endIso)
          .order('tanggal', ascending: false);

      int totalPengeluaran = expenses.fold(0, (sum, item) => sum + (item['harga'] as int));

      return {
        'pemasukan': totalPemasukan,
        'pengeluaran': totalPengeluaran,
        'laba_bersih': totalPemasukan - totalPengeluaran,
        'detail_pemasukan': payments,
        'detail_pengeluaran': expenses,
      };
    } catch (e) {
      throw Exception('Gagal menarik laporan: $e');
    }
  }

  // FUNGSI BARU: MEMBUAT LAPORAN PDF (DENGAN FORMAT RUPIAH)
  Future<void> generateReportPdf(Map<String, dynamic> data, DateTime start, DateTime end, String type) async {
    final pdf = pw.Document();
    final dateStr = '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
    
    // ALAT FORMAT RUPIAH (Otomatis memberi titik setiap 3 angka)
    final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    List<List<String>> tableData = [];
    List<String> headers = [];
    
    if (type == 'Pemasukan') {
      headers = ['No', 'Tanggal', 'Pelanggan', 'Layanan', 'Barber', 'Nominal'];
      final List payments = data['detail_pemasukan'];
      var sortedPayments = List.from(payments)..sort((a, b) => DateTime.parse(a['jadwal']).compareTo(DateTime.parse(b['jadwal'])));
      
      int i = 1;
      for (var p in sortedPayments) {
        final date = DateTime.parse(p['jadwal']).toLocal();
        final tgl = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
        
        List details = p['order_details'];
        String layanan = details.map((d) => d['treatments']['treatment']).join(', ');
        String barber = details.map((d) => d['barbers']['users']['username']).toSet().join(', ');
        
        tableData.add([(i++).toString(), tgl, p['nama'] ?? '-', layanan, barber, formatRp.format(p['total_harga'])]);
      }
    } else if (type == 'Pengeluaran') {
      headers = ['No', 'Tanggal', 'Kategori', 'Keterangan', 'Nominal'];
      final List expenses = data['detail_pengeluaran'];
      var sortedExpenses = List.from(expenses)..sort((a, b) => DateTime.parse(a['tanggal']).compareTo(DateTime.parse(b['tanggal'])));
      
      int i = 1;
      for (var e in sortedExpenses) {
        final date = DateTime.parse(e['tanggal']).toLocal();
        final tgl = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
        
        tableData.add([(i++).toString(), tgl, e['kategori'], e['keterangan'] ?? '-', formatRp.format(e['harga'])]);
      }
    } else {
      headers = ['No', 'Tanggal', 'Keterangan', 'Pemasukan', 'Pengeluaran'];
      List<Map<String, dynamic>> combined = [];
      
      for (var p in data['detail_pemasukan']) {
        combined.add({
          'date': DateTime.parse(p['jadwal']).toLocal(),
          'desc': 'Pemasukan (Pelanggan: ${p['nama'] ?? '-'})',
          'in': p['total_harga'],
          'out': 0
        });
      }
      for (var e in data['detail_pengeluaran']) {
        combined.add({
          'date': DateTime.parse(e['tanggal']).toLocal(),
          'desc': 'Pengeluaran (${e['kategori']}) - ${e['keterangan'] ?? ''}',
          'in': 0,
          'out': e['harga']
        });
      }
      
      combined.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      
      int i = 1;
      for (var item in combined) {
        final date = item['date'] as DateTime;
        final tgl = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
        tableData.add([
          (i++).toString(), tgl, item['desc'], 
          item['in'] > 0 ? formatRp.format(item['in']) : '-',
          item['out'] > 0 ? formatRp.format(item['out']) : '-'
        ]);
      }
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Center(child: pw.Text('LAPORAN KEUANGAN ($type)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Bintangss Barbershop', style: const pw.TextStyle(fontSize: 12))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Periode: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
            pw.SizedBox(height: 24),
            
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              headerHeight: 25,
              cellHeight: 25,
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              headers: headers,
              data: tableData,
            ),
            
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // PENERAPAN FORMAT RUPIAH DI BAGIAN TOTAL KESELURUHAN
                      if (type == 'Pemasukan' || type == 'Semua') pw.Text('Total Pemasukan : ${formatRp.format(data['pemasukan'])}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      if (type == 'Pengeluaran' || type == 'Semua') pw.Text('Total Pengeluaran: ${formatRp.format(data['pengeluaran'])}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      if (type == 'Semua') pw.Divider(),
                      if (type == 'Semua') pw.Text('Laba Bersih       : ${formatRp.format(data['laba_bersih'])}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ]
                  )
                )
              ]
            )
          ];
        }
      )
    );
    
    final now = DateTime.now();
    final String fileName = 'Laporan_${type}_${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName,
    );
  }
}