import 'package:flutter/material.dart';
import '../services/user_service.dart';

class UserManagementScreen extends StatefulWidget {
  final int roleId; // Menangkap roleId dari Dashboard
  
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
            title: Text(isEdit ? 'Edit Pegawai' : 'Tambah Pegawai'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  if (!isEdit) 
                    TextField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                  const SizedBox(height: 16),
                  
                  // PERBAIKAN WARNING: 'value' diganti menjadi 'initialValue'
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
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEdit ? 'Profil diperbarui!' : 'Pegawai ditambahkan!')),
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
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.blueGrey : Colors.grey,
                    child: Icon(
                      roleName == 'Owner' ? Icons.star : (roleName == 'Kasir' ? Icons.point_of_sale : Icons.cut),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    user['username'], 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                    )
                  ),
                  subtitle: Text('Jabatan: $roleName'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // PERBAIKAN WARNING: 'activeColor' diganti 'activeThumbColor'
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
                            
                            // PERBAIKAN ASYNC GAP: Memastikan layar masih ada sebelum mengeksekusi UI
                            if (!mounted) return;
                            _refreshData(); 
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                      
                      // PROTEKSI JABATAN: Tombol Edit HANYA muncul jika yang login adalah Owner (roleId = 1)
                      if (widget.roleId == 1)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueGrey),
                          onPressed: () => _showFormDialog(existingUser: user),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      
      // PROTEKSI JABATAN: Tombol Tambah HANYA muncul jika yang login adalah Owner
      floatingActionButton: widget.roleId == 1
          ? FloatingActionButton(
              onPressed: () => _showFormDialog(),
              child: const Icon(Icons.add),
            )
          : null, // Jika Kasir, tidak ada tombol
    );
  }
}