import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  
  // 1. FUNGSI UNTUK MENCETAK NOTA KASIR
  static Future<void> generateNota({
    required String namaNota,
    required String namaCustomer,
    required int totalHarga,
    required DateTime tanggal,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();
    final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final tglString = '${tanggal.day.toString().padLeft(2, '0')} ${months[tanggal.month - 1]} ${tanggal.year.toString().substring(2)} (${tanggal.hour.toString().padLeft(2, '0')}:${tanggal.minute.toString().padLeft(2, '0')})';

    final customFormat = PdfPageFormat(80 * PdfPageFormat.mm, 105 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm);

    final logoImageBytes = await rootBundle.load('assets/images/logo.jpg');
    final logoImage = pw.MemoryImage(logoImageBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: customFormat, 
        build: (pw.Context context) {
          const double fSize = 9; 

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Image(logoImage, height: 40), 
              ),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('+62 895-6095-13838', style: const pw.TextStyle(fontSize: fSize))),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              
              if (namaCustomer.isNotEmpty) pw.Text('Pelanggan : $namaCustomer', style: const pw.TextStyle(fontSize: fSize)),
              pw.Text('Tanggal : $tglString', style: const pw.TextStyle(fontSize: fSize)),
              pw.Text('Nota : $namaNota', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              
              pw.Expanded(
                child: pw.ListView(
                  children: items.map((item) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item['treatmentName'], style: pw.TextStyle(fontSize: fSize, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Barber: ${item['barberName']}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.SizedBox(width: 10), 
                          pw.Text('${item['jumlah']} x ${formatRp.format(item['harga'])}', style: const pw.TextStyle(fontSize: fSize)),
                          pw.Text(formatRp.format(item['harga'] * item['jumlah']), style: const pw.TextStyle(fontSize: fSize)),
                        ]
                      ),
                      pw.SizedBox(height: 4), 
                    ]
                  )).toList(),
                )
              ),
              
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text(formatRp.format(totalHarga), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('Terima Kasih', style: const pw.TextStyle(fontSize: fSize, color: PdfColors.grey600))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: namaNota);
  }

  // 2. FUNGSI UNTUK MENCETAK LAPORAN KEUANGAN PDF
  static Future<void> generateLaporan({
    required Map<String, dynamic> data, 
    required DateTime start, 
    required DateTime end, 
    required String type,
  }) async {
    final pdf = pw.Document();
    final dateStr = '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
    final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    List<List<String>> tableData = [];
    List<String> headers = [];
    
    if (type == 'Pemasukan') {
      // PERBAIKAN: Menambahkan kolom 'Metode'
      headers = ['No', 'Tanggal', 'Pelanggan', 'Layanan', 'Barber', 'Metode', 'Nominal'];
      final List payments = data['detail_pemasukan'];
      var sortedPayments = List.from(payments)..sort((a, b) => DateTime.parse(a['jadwal']).compareTo(DateTime.parse(b['jadwal'])));
      
      int i = 1;
      for (var p in sortedPayments) {
        final date = DateTime.parse(p['jadwal']).toLocal();
        final tgl = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
        List details = p['order_details'];
        String layanan = details.map((d) => d['treatments']['treatment']).join(', ');
        String barber = details.map((d) => d['barbers']['users']['username']).toSet().join(', ');
        
        // Menarik via_payment
        String viaName = p['via_payments'] != null ? p['via_payments']['via'] : '-';

        tableData.add([(i++).toString(), tgl, p['nama'] ?? '-', layanan, barber, viaName, formatRp.format(p['total_harga'])]);
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
        // PERBAIKAN: Menambahkan Via Payment ke dalam keterangan
        String viaName = p['via_payments'] != null ? p['via_payments']['via'] : '-';
        combined.add({ 
          'date': DateTime.parse(p['jadwal']).toLocal(), 
          'desc': 'Pemasukan (Pelanggan: ${p['nama'] ?? '-'} | Via: $viaName)', 
          'in': p['total_harga'], 
          'out': 0 
        });
      }
      for (var e in data['detail_pengeluaran']) {
        combined.add({ 'date': DateTime.parse(e['tanggal']).toLocal(), 'desc': 'Pengeluaran (${e['kategori']}) - ${e['keterangan'] ?? ''}', 'in': 0, 'out': e['harga'] });
      }
      combined.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      int i = 1;
      for (var item in combined) {
        final date = item['date'] as DateTime;
        final tgl = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
        tableData.add([ (i++).toString(), tgl, item['desc'], item['in'] > 0 ? formatRp.format(item['in']) : '-', item['out'] > 0 ? formatRp.format(item['out']) : '-' ]);
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
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: fileName);
  }

  // 3. FUNGSI BARU: MENCETAK LAPORAN JADWAL BOOKING
  static Future<void> generateBookingReport({
    required List<Map<String, dynamic>> data,
    required DateTime start,
    required DateTime end,
  }) async {
    final pdf = pw.Document();
    final dateStr = '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Center(child: pw.Text('LAPORAN JADWAL BOOKING', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
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
              cellAlignments: {
                0: pw.Alignment.center, 1: pw.Alignment.center, 2: pw.Alignment.center,
                3: pw.Alignment.centerLeft, 4: pw.Alignment.centerLeft, 5: pw.Alignment.center,
              },
              headers: ['No', 'Tanggal', 'Jam', 'Pelanggan', 'Barber', 'Status'],
              data: List<List<String>>.generate(
                data.length,
                (index) {
                  final b = data[index];
                  final jadwal = DateTime.parse(b['jadwal']).toLocal();
                  final tgl = '${jadwal.day.toString().padLeft(2, '0')}/${jadwal.month.toString().padLeft(2, '0')}/${jadwal.year}';
                  final jam = '${jadwal.hour.toString().padLeft(2, '0')}:${jadwal.minute.toString().padLeft(2, '0')}';
                  final nama = b['nama'] ?? '-';
                  final barber = b['barbers'] != null ? b['barbers']['users']['username'] : 'Bebas';
                  
                  String status = b['status']?.toString() ?? 'Aktif';
                  status = status.substring(0, 1).toUpperCase() + status.substring(1).toLowerCase();

                  return [(index + 1).toString(), tgl, jam, nama, barber, status];
                },
              ),
            ),
          ];
        },
      ),
    );

    final now = DateTime.now();
    final String fileName = 'Laporan_Booking_${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName, 
    );
  }
}