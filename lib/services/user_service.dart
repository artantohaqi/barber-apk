import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  // Menambahkan parameter currentUserRoleId
  Future<List<Map<String, dynamic>>> getUsers(int currentUserRoleId) async {
    try {
      // 1. Base Query (Hanya select)
      var query = _supabase
          .from('users')
          .select('id, username, is_active, role_id, roles(role_name)');
          
      // 2. Filter (Wajib sebelum order)
      if (currentUserRoleId == 2) {
        query = query.eq('role_id', 3);
      }
      
      // 3. Modifier (.order diletakkan paling akhir sebelum di-await)
      return await query.order('id', ascending: true);
    } catch (e) {
      throw Exception('Gagal menarik data user: $e');
    }
  }

  Future<void> createUser(String username, String password, int roleId) async {
    try {
      // 1. TRIK KLIEN BAYANGAN (GHOST CLIENT) DENGAN BYPASS PKCE
      final ghostClient = SupabaseClient(
        'https://azfanpxgsesbczyxdxob.supabase.co',
        'sb_publishable_YukE_NKrMdF-sZfLW2elvQ_J6G4JN2F',
        authOptions: const AuthClientOptions( // PERBAIKAN: Gunakan AuthClientOptions
          authFlowType: AuthFlowType.implicit, 
        ),
      );

      final String dummyEmail = '$username@binkas.com'.toLowerCase();

      // 2. Tembakkan data pendaftaran ke Supabase Auth
      await ghostClient.auth.signUp(
        email: dummyEmail,
        password: password,
      );

      // 3. Segera hancurkan klien bayangan
      ghostClient.dispose();

      // 4. Lanjutkan memasukkan profil ke tabel public.users menggunakan Klien Utama
      await _supabase.rpc('create_new_user', params: {
        'p_username': username,
        'p_password': password, 
        'p_role_id': roleId,
      });
      
    } catch (e) {
      throw Exception('Gagal membuat pegawai baru: $e');
    }
  }

  // FITUR BARU: Edit Data User Dasar
  Future<void> editUser(int userId, String username, int roleId) async {
    try {
      await _supabase.from('users').update({
        'username': username,
        'role_id': roleId,
      }).eq('id', userId);

      // Logika Sinkronisasi: Jika role diubah menjadi Barber (3)
      if (roleId == 3) {
        final check = await _supabase.from('barbers').select('id').eq('user_id', userId);
        if (check.isEmpty) {
          await _supabase.from('barbers').insert({'user_id': userId, 'is_active': true});
        } else {
          await _supabase.from('barbers').update({'is_active': true}).eq('user_id', userId);
        }
      } else {
        // Jika diubah dari Barber ke Kasir/Owner, hilangkan dari layar POS
        await _supabase.from('barbers').update({'is_active': false}).eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Gagal mengedit user: $e');
    }
  }

  // FITUR BARU: Toggle Slider Aktif/Nonaktif
  Future<void> toggleUserStatus(int userId, int roleId, bool isActive) async {
    try {
      await _supabase.from('users').update({'is_active': isActive}).eq('id', userId);
      
      // Jika dia Barber, matikan juga di tabel barbers
      if (roleId == 3) {
        await _supabase.from('barbers').update({'is_active': isActive}).eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Gagal mengubah status: $e');
    }
  }

  // FITUR BARU: Menghitung Total Komisi Barber Bulan Ini (Logika Filter Dart)
  Future<Map<String, dynamic>> getBarberCommissionThisMonth(int userId) async {
    try {
      final now = DateTime.now();

      // 1. Cari ID Barber yang terikat dengan User ID ini
      final barberData = await _supabase.from('barbers').select('id').eq('user_id', userId).maybeSingle();
      if (barberData == null) return {'total': 0, 'details': []};
      
      // 2. Tarik riwayat layanan TANPA filter inner join Supabase untuk menghindari error relasi
      final response = await _supabase
          .from('order_details')
          .select('jumlah, treatments(treatment, komisi), payments(jadwal)')
          .eq('barber_id', barberData['id']);

      int totalKomisi = 0;
      List<Map<String, dynamic>> details = [];

      for (var row in response) {
        // Abaikan jika data pembayaran tidak ditemukan
        if (row['payments'] == null) continue;

        final jadwalStr = row['payments']['jadwal'];
        final jadwalDate = DateTime.parse(jadwalStr).toLocal();

        // 3. Filter Manual: Pastikan transaksi terjadi di bulan dan tahun yang sama dengan hari ini
        if (jadwalDate.month == now.month && jadwalDate.year == now.year) {
          final treatment = row['treatments']['treatment'];
          // Gunakan fallback ke 0 atau 1 jika nilainya kebetulan kosong di database
          final komisiSatuan = row['treatments']['komisi'] ?? 0;
          final qty = row['jumlah'] ?? 1;
          final subtotal = (komisiSatuan as int) * (qty as int);

          totalKomisi += subtotal;
          details.add({
            'tanggal': jadwalStr,
            'treatment': treatment,
            'qty': qty,
            'subtotal': subtotal,
          });
        }
      }

      // 4. Urutkan rincian komisi dari transaksi yang paling baru (kronologis)
      details.sort((a, b) => DateTime.parse(b['tanggal']).compareTo(DateTime.parse(a['tanggal'])));

      return {'total': totalKomisi, 'details': details};
    } catch (e) {
      // Jika masih ada error, cetak ke terminal agar kita tahu penyebabnya
      print('DEBUG ERROR KOMISI: $e');
      return {'total': 0, 'details': []};
    }
  }
}