import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';

import 'user_management_screen.dart';
import 'via_payment_screen.dart';
import 'treatment_screen.dart';
import 'pos_screen.dart';
import 'booking_screen.dart';
import 'expense_screen.dart';
import 'report_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int roleId;
  const DashboardScreen({super.key, required this.roleId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _service = DashboardService();
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getDashboardMetrics();
      if (!mounted) return;
      setState(() {
        _metrics = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blueGrey),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.cut, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                const Text('BINKAS POS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (widget.roleId == 1 || widget.roleId == 2)
            ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('Manajemen User'), onTap: () => _nav(context, UserManagementScreen(roleId: widget.roleId))),
          if (widget.roleId == 1)
            ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('Metode Pembayaran'), onTap: () => _nav(context, const ViaPaymentScreen())),
          if (widget.roleId == 1)
            ListTile(leading: const Icon(Icons.cut), title: const Text('Layanan & Harga'), onTap: () => _nav(context, const TreatmentScreen())),
          if (widget.roleId == 1 || widget.roleId == 2)
            ListTile(leading: const Icon(Icons.point_of_sale), title: const Text('Kasir / Payment'), onTap: () => _nav(context, const PosScreen())),
          ListTile(leading: const Icon(Icons.calendar_month), title: const Text('Jadwal Booking'), onTap: () => _nav(context, BookingScreen(roleId: widget.roleId))),
          if (widget.roleId == 1 || widget.roleId == 2)
            ListTile(leading: const Icon(Icons.money_off), title: const Text('Pengeluaran'), onTap: () => _nav(context, const ExpenseScreen())),
          if (widget.roleId == 1)
            ListTile(leading: const Icon(Icons.analytics), title: const Text('Laporan Keuangan'), onTap: () => _nav(context, const ReportScreen())),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red), 
            title: const Text('Keluar', style: TextStyle(color: Colors.red)), 
            onTap: () => Navigator.pushReplacementNamed(context, '/')
          ),
        ],
      ),
    );
  }

  void _nav(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen)).then((_) => _loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    // INISIALISASI FORMATTER RUPIAH
    final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // PERBAIKAN: Format angka pemasukan dan pengeluaran
                      Expanded(child: _buildMetricCard('Pemasukan', formatRp.format(_metrics!['incomeToday']), Colors.green, Icons.trending_up)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('Pengeluaran', formatRp.format(_metrics!['expenseToday']), Colors.red, Icons.trending_down)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard('Pelanggan Hadir', '${_metrics!['customersToday']} Orang', Colors.blueGrey, Icons.people),
                  
                  const SizedBox(height: 32),
                  const Text('Trend Pemasukan Bulan Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                    child: _buildChart(_metrics!['trendData'] as Map<int, int>),
                  ),

                  const SizedBox(height: 32),
                  const Text('Layanan Terpopuler (Minggu Ini)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(_metrics!['popularTreatments'] as List<MapEntry<String, int>>).map((entry) => 
                    ListTile(
                      leading: const Icon(Icons.star, color: Colors.orange),
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('${entry.value}x', style: const TextStyle(fontSize: 16)),
                      contentPadding: EdgeInsets.zero,
                    )
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildChart(Map<int, int> trendData) {
    if (trendData.isEmpty) return const Center(child: Text('Belum ada data bulan ini'));

    List<FlSpot> spots = trendData.entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();
    spots.sort((a, b) => a.x.compareTo(b.x));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 5)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blueGrey,
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: Colors.blueGrey.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }
}