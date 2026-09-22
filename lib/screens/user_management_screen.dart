import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';

class UserManagementScreen extends StatefulWidget {
  final int roleId;
  
  const UserManagementScreen({super.key, required this.roleId});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _usersFuture = _userService.getUsers(widget.roleId);
    });
  }

  void _showFormDialog({Map<String, dynamic>? existingUser}) {
    final isEdit = existingUser != null;
    final usernameCtrl = TextEditingController(text: isEdit ? existingUser['username'] : '');
    final passwordCtrl = TextEditingController();
    int selectedRole = isEdit ? existingUser['role_id'] : 2; 
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Jabatan Pegawai' : 'Tambah Pegawai Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. KOLOM USERNAME (Terkunci saat mode Edit)
                  TextField(
                    controller: usernameCtrl,
                    readOnly: isEdit, // Mematikan input keyboard jika sedang mengedit
                    decoration: InputDecoration(
                      labelText: 'Username',
                      filled: isEdit,
                      fillColor: isEdit ? Colors.grey.shade200 : null,
                      suffixIcon: isEdit ? const Icon(Icons.lock, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 2. KOLOM PASSWORD (Berubah menjadi informasi visual saat Edit)
                  if (isEdit)
                    TextField(
                      readOnly: true,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: '********',
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        suffixIcon: const Icon(Icons.security, color: Colors.grey),
                        helperText: 'Sandi dienkripsi oleh sistem. Lakukan Reset via Dasbor Supabase jika lupa.',
                        helperMaxLines: 2,
                      ),
                    )
                  else 
                    TextField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                  const SizedBox(height: 16),
                  
                  // 3. KOLOM ROLE (Satu-satunya yang bisa diubah saat Edit)
                  DropdownButtonFormField<int>(
                    initialValue: selectedRole, 
                    decoration: const InputDecoration(labelText: 'Jabatan'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Owner')),
                      DropdownMenuItem(value: 2, child: Text('Kasir')),
                      DropdownMenuItem(value: 3, child: Text('Barber')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('Batal')),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (usernameCtrl.text.isEmpty) return;
                  if (!isEdit && passwordCtrl.text.isEmpty) return;
                  
                  setDialogState(() => isSaving = true);
                  try {
                    if (isEdit) {
                      await _userService.editUser(existingUser['id'], usernameCtrl.text.trim(), selectedRole);
                    } else {
                      await _userService.createUser(usernameCtrl.text.trim(), passwordCtrl.text.trim(), selectedRole);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _refreshData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Jabatan diperbarui!' : 'Pegawai ditambahkan!')));
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
      appBar: AppBar(title: const Text('Manajemen User')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Belum ada data user.'));

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final roleName = user['roles']['role_name'];
              final bool isActive = user['is_active'];
              final bool isBarber = user['role_id'] == 3;
              
              // Widget Trailing (Tombol Switch & Edit)
              Widget trailingActions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: isActive,
                    activeThumbColor: Colors.green,
                    onChanged: (bool newValue) async {
                      if (user['id'] == 1 && newValue == false) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun Owner Utama tidak boleh dinonaktifkan!')));
                        return;
                      }
                      try {
                        await _userService.toggleUserStatus(user['id'], user['role_id'], newValue);
                        if (!mounted) return;
                        _refreshData(); 
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                  ),
                  if (widget.roleId == 1)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      onPressed: () => _showFormDialog(existingUser: user),
                    ),
                ],
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                // JIKA DIA BARBER, GUNAKAN EXPANSION TILE (BISA DI-DROPDOWN)
                child: isBarber 
                  ? ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.blueGrey : Colors.grey,
                        child: const Icon(Icons.cut, color: Colors.white, size: 20),
                      ),
                      title: Text(user['username'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough)),
                      subtitle: Text('Jabatan: $roleName'),
                      trailing: trailingActions,
                      children: [
                        _BarberCommissionDetail(userId: user['id'], userService: _userService),
                      ],
                    )
                  // JIKA OWNER ATAU KASIR, TETAP GUNAKAN LIST TILE BIASA
                  : ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.blueGrey : Colors.grey,
                        child: Icon(roleName == 'Owner' ? Icons.star : Icons.point_of_sale, color: Colors.white, size: 20),
                      ),
                      title: Text(user['username'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough)),
                      subtitle: Text('Jabatan: $roleName'),
                      trailing: trailingActions,
                    ),
              );
            },
          );
        },
      ),
      floatingActionButton: widget.roleId == 1
          ? FloatingActionButton(onPressed: () => _showFormDialog(), child: const Icon(Icons.add))
          : null,
    );
  }
}

// COMPONENT BARU: Widget Rincian Komisi di dalam Dropdown
class _BarberCommissionDetail extends StatelessWidget {
  final int userId;
  final UserService userService;
  const _BarberCommissionDetail({required this.userId, required this.userService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: userService.getBarberCommissionThisMonth(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!['details'].isEmpty) {
          return const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada riwayat komisi bulan ini.', style: TextStyle(color: Colors.grey)));
        }

        final data = snapshot.data!;
        final details = data['details'] as List;
        final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

        return Container(
          color: Colors.blueGrey.shade50,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rincian Komisi Bulan Ini:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 12),
              
              // Daftar Treatment yang sudah dikerjakan
              ...details.map((d) {
                final tgl = DateTime.parse(d['tanggal']).toLocal();
                // FORMAT TANGGAL DAN JAM SECARA SPESIFIK
                final String waktuTransaksi = '${tgl.day.toString().padLeft(2, '0')}/${tgl.month.toString().padLeft(2, '0')} (${tgl.hour.toString().padLeft(2, '0')}:${tgl.minute.toString().padLeft(2, '0')})';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start, // Agar teks sejajar rapi jika panjang
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // MENAMPILKAN TANGGAL DAN JAM
                            Text(waktuTransaksi, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            // MENAMPILKAN NAMA TREATMENT DAN QTY
                            Text('${d['treatment']} (x${d['qty']})', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      // MENAMPILKAN SUBTOTAL KOMISI
                      Text(formatRp.format(d['subtotal']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                );
              }),
              
              const Divider(thickness: 1.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Komisi Diterima', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(formatRp.format(data['total']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}