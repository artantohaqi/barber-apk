import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../services/booking_service.dart';
import '../services/pos_service.dart';
import 'checkout_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

class BookingScreen extends StatefulWidget {
  final int roleId;
  const BookingScreen({super.key, required this.roleId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final BookingService _bookingService = BookingService();
  final PosService _posService = PosService();
  
  final CalendarController _calendarController = CalendarController();
  
  List<Appointment> _appointments = [];
  List<Map<String, dynamic>> _barbers = [];
  List<Map<String, dynamic>> _treatments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataMaster();
  }

  Future<void> _loadDataMaster() async {
    try {
      final barbers = await _posService.getActiveBarbers();
      final treatments = await _posService.getActiveTreatments();
      await _fetchBookings();
      
      if (!mounted) return;
      setState(() {
        _barbers = barbers;
        _treatments = treatments;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _fetchBookings() async {
    final data = await _bookingService.getBookings();
    final List<Appointment> meetings = data.map((b) {
      final barberName = b['barbers'] != null ? b['barbers']['users']['username'] : 'Bebas (Siapa Saja)';
      return Appointment(
        id: b['id'],
        startTime: DateTime.parse(b['jadwal']).toLocal(),
        endTime: DateTime.parse(b['jadwal_selesai']).toLocal(),
        subject: '${b['nama']} ($barberName)',
        color: b['barbers'] == null ? Colors.orange : Colors.indigo, 
        notes: jsonEncode(b), 
      );
    }).toList();

    setState(() => _appointments = meetings);
  }

  void _showBookingForm(DateTime selectedTime, {Map<String, dynamic>? existingData}) {
    final isEdit = existingData != null;
    
    final namaCtrl = TextEditingController(text: isEdit ? existingData['nama'] : '');
    final noHpCtrl = TextEditingController(text: isEdit ? existingData['no_hp'] : '');
    final extraTimeCtrl = TextEditingController(text: isEdit ? existingData['extra_time'].toString() : '0');
    
    int? selectedBarberId = isEdit ? existingData['barber_id'] : null;
    
    List<Map<String, dynamic>> checkedTreatments = [];
    if (isEdit && existingData['detail_treatments'] != null) {
      List<dynamic> parsed = existingData['detail_treatments'] is String 
          ? jsonDecode(existingData['detail_treatments']) 
          : existingData['detail_treatments'];
      checkedTreatments = parsed.map((e) => e as Map<String, dynamic>).toList();
    }

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) { // PERBAIKAN: Pisahkan penamaan context
        return StatefulBuilder(builder: (dialogContext, setModalState) { // PERBAIKAN: Gunakan dialogContext
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom, top: 16, left: 16, right: 16),
            child: SizedBox(
              height: MediaQuery.of(dialogContext).size.height * 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isEdit ? 'Edit Jadwal Booking' : 'Buat Jadwal Baru', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Tgl & Waktu: ${selectedTime.toString().substring(0, 16)}', style: const TextStyle(color: Colors.blueGrey)),
                  const Divider(),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Pelanggan')),
                          TextField(controller: noHpCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No HP')),
                          const SizedBox(height: 16),
                          
                          InputDecorator(
                            decoration: const InputDecoration(labelText: 'Pilih Barber', border: OutlineInputBorder()),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: selectedBarberId,
                                isDense: true,
                                items: [
                                  const DropdownMenuItem<int?>(value: null, child: Text('Bebas (Siapa Saja)')),
                                  ..._barbers.map((b) => DropdownMenuItem<int?>(value: b['id'], child: Text(b['users']['username'])))
                                ],
                                onChanged: (val) => setModalState(() => selectedBarberId = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: extraTimeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Tambahan Waktu (Menit)', suffixText: 'Menit', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 16),

                          const Align(alignment: Alignment.centerLeft, child: Text('Layanan (Wajib pilih minimal satu):', style: TextStyle(fontWeight: FontWeight.bold))),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _treatments.length,
                              itemBuilder: (context, i) {
                                final t = _treatments[i];
                                final isChecked = checkedTreatments.any((item) => item['id'] == t['id']);
                                return CheckboxListTile(
                                  title: Text('${t['treatment']} (${t['waktu_menit']} mnt)'),
                                  value: isChecked,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        checkedTreatments.add(t);
                                      } else {
                                        checkedTreatments.removeWhere((item) => item['id'] == t['id']);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Tombol Aksi Bawah
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (isEdit)
                              IconButton(
                                icon: const Icon(Icons.event_busy, color: Colors.red), // Ikon kalender silang
                                tooltip: 'Batalkan Jadwal',
                                onPressed: () async {
                                  // Memanggil fungsi Batal, bukan Delete
                                  await _bookingService.cancelBooking(existingData['id']);
                                  
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(dialogContext); 
                                  _fetchBookings(); // Refresh kalender (jadwal batal akan otomatis hilang dari layar)
                                  
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jadwal dibatalkan!')));
                                  }
                                },
                              ),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSaving ? null : () async {
                                  if (namaCtrl.text.isEmpty || checkedTreatments.isEmpty) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Nama dan Layanan wajib diisi!')));
                                    return;
                                  }

                                  setModalState(() => isSaving = true);
                                  try {
                                    if (isEdit) {
                                      await _bookingService.updateBooking(
                                        bookingId: existingData['id'], nama: namaCtrl.text, noHp: noHpCtrl.text,
                                        jadwalMulai: selectedTime, barberId: selectedBarberId,
                                        treatments: checkedTreatments, extraTime: int.parse(extraTimeCtrl.text.isEmpty ? '0' : extraTimeCtrl.text),
                                      );
                                    } else {
                                      await _bookingService.createBooking(
                                        nama: namaCtrl.text, noHp: noHpCtrl.text, jadwalMulai: selectedTime,
                                        barberId: selectedBarberId, treatments: checkedTreatments,
                                        extraTime: int.parse(extraTimeCtrl.text.isEmpty ? '0' : extraTimeCtrl.text),
                                      );
                                    }
                                    if (!dialogContext.mounted) return;
                                    Navigator.pop(dialogContext); // PERBAIKAN: Tutup dialogContext
                                    _fetchBookings();
                                    
                                    // Tampilkan pesan sukses di context utama layar Booking
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jadwal tersimpan!')));
                                    }
                                  } catch (e) {
                                    setModalState(() => isSaving = false);
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(e.toString())));
                                    }
                                  }
                                },
                                child: isSaving ? const CircularProgressIndicator() : const Text('SIMPAN PERUBAHAN JADWAL'),
                              ),
                            ),
                          ],
                        ),
                        
                        if (isEdit) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('SELESAI & LANJUT BAYAR', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                if (selectedBarberId == null) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('Tentukan Barber secara definitif terlebih dahulu sebelum membayar!'))
                                  );
                                  return;
                                }

                                final cart = Provider.of<CartProvider>(context, listen: false);
                                cart.clearCart(); 

                                final namaBarber = _barbers.firstWhere((b) => b['id'] == selectedBarberId)['users']['username'];

                                for (var t in checkedTreatments) {
                                  cart.addItem(CartItem(
                                    barberId: selectedBarberId!,
                                    barberName: namaBarber,
                                    treatmentId: t['id'],
                                    treatmentName: t['treatment'],
                                    harga: t['harga'],
                                    komisi: t['komisi'],
                                  ));
                                }

                                Navigator.pop(dialogContext); // PERBAIKAN: Tutup form
                                
                                Navigator.push(
                                  context, // Menggunakan context utama untuk pindah layar
                                  MaterialPageRoute(
                                    builder: (context) => CheckoutScreen(
                                      initialNama: namaCtrl.text,
                                      initialNoHp: noHpCtrl.text,
                                      bookingId: existingData['id'],
                                    ),
                                  ),
                                ).then((_) => _fetchBookings()); 
                              },
                            ),
                          ),
                        ]
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Booking'),
        actions: [
          // FITUR BARU: Tombol Download Laporan (HANYA OWNER & KASIR)
          if (widget.roleId == 1 || widget.roleId == 2)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: 'Download Laporan Booking',
              onPressed: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 365)), 
                );
                
                if (picked != null) {
                  setState(() => _isLoading = true);
                  try {
                    await _bookingService.generateBookingReport(picked.start, picked.end);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                }
              },
            ),

          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Pilih Tanggal',
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: _calendarController.displayDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selected != null) {
                setState(() {
                  _calendarController.displayDate = selected;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDataMaster();
            },
          )
        ],
      ),
      body: SfCalendar(
        controller: _calendarController,
        view: CalendarView.timelineDay, 
        dataSource: BookingDataSource(_appointments),
        timeSlotViewSettings: const TimeSlotViewSettings(
          startHour: 10, 
          endHour: 22, 
          timeInterval: Duration(minutes: 20), 
          timeFormat: 'HH:mm',
        ),
        onTap: (CalendarTapDetails details) {
          if (widget.roleId == 1 || widget.roleId == 2) {
            if (details.targetElement == CalendarElement.calendarCell) {
              _showBookingForm(details.date!);
            } else if (details.targetElement == CalendarElement.appointment) {
              final app = details.appointments!.first as Appointment;
              final dataMentah = jsonDecode(app.notes!);
              _showBookingForm(app.startTime, existingData: dataMentah);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barber hanya bisa melihat jadwal.')));
          }
        },
      ),
    );
  }
}

class BookingDataSource extends CalendarDataSource {
  BookingDataSource(List<Appointment> source) { appointments = source; }
}