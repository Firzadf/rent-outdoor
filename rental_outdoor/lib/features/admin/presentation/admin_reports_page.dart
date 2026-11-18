import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/admin_repository.dart';
import '../domain/admin_report.dart';

/// Halaman laporan admin — pendapatan dan laporan alat.
class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Default: awal bulan ini sampai hari ini
  late DateTime _startDate;
  late DateTime _endDate;
  String _period = 'daily';

  bool _loadingRevenue = false;
  String? _revenueError;
  RevenueReport? _revenueReport;

  bool _loadingEquipment = false;
  String? _equipmentError;
  EquipmentReport? _equipmentReport;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    _loadRevenue();
    _loadEquipmentReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRevenue() async {
    setState(() {
      _loadingRevenue = true;
      _revenueError = null;
    });
    try {
      final result = await ref.read(adminRepositoryProvider).getRevenueReport(
            startDate: _startDate,
            endDate: _endDate,
            period: _period,
          );
      if (!mounted) return;
      setState(() {
        _revenueReport = result;
        _loadingRevenue = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _revenueError = e.message;
        _loadingRevenue = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _revenueError = 'Gagal memuat laporan pendapatan.';
        _loadingRevenue = false;
      });
    }
  }

  Future<void> _loadEquipmentReport() async {
    setState(() {
      _loadingEquipment = true;
      _equipmentError = null;
    });
    try {
      final result =
          await ref.read(adminRepositoryProvider).getEquipmentReport(
                startDate: _startDate,
                endDate: _endDate,
              );
      if (!mounted) return;
      setState(() {
        _equipmentReport = result;
        _loadingEquipment = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _equipmentError = e.message;
        _loadingEquipment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _equipmentError = 'Gagal memuat laporan alat.';
        _loadingEquipment = false;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      locale: const Locale('id', 'ID'),
    );
    if (picked == null || !mounted) return;
    setState(() => _startDate = picked);
    _loadRevenue();
    _loadEquipmentReport();
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = picked);
    _loadRevenue();
    _loadEquipmentReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pendapatan'),
            Tab(text: 'Alat'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDateFilter(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRevenueTab(),
                  _buildEquipmentTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  'Dari',
                  _startDate,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateButton(
                  'Sampai',
                  _endDate,
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _periodChip('daily', 'Harian'),
              const SizedBox(width: 8),
              _periodChip('monthly', 'Bulanan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateButton(
    String label,
    DateTime date, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  formatDate(formatIsoDate(date)),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String value, String label) {
    final selected = _period == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _period = value);
        _loadRevenue();
      },
    );
  }

  Widget _buildRevenueTab() {
    if (_loadingRevenue) {
      return const LoadingView(message: 'Memuat laporan pendapatan...');
    }
    if (_revenueError != null) {
      return ErrorView(message: _revenueError!, onRetry: _loadRevenue);
    }
    final report = _revenueReport;
    if (report == null || report.rows.isEmpty) {
      return const EmptyView(
        message: 'Tidak ada data pendapatan dalam rentang tanggal ini.',
        icon: Icons.bar_chart_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevenueSummary(report),
          const SizedBox(height: 16),
          _buildBarChart(report),
          const SizedBox(height: 16),
          _buildRevenueTable(report),
        ],
      ),
    );
  }

  Widget _buildRevenueSummary(RevenueReport report) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Pendapatan',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(report.totalRevenue),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Pesanan',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${report.totalOrders}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Grafik batang sederhana menggunakan widget bawaan Flutter.
  Widget _buildBarChart(RevenueReport report) {
    if (report.rows.isEmpty) return const SizedBox();

    final maxRevenue =
        report.rows.map((r) => r.revenue).reduce((a, b) => a > b ? a : b);
    if (maxRevenue <= 0) return const SizedBox();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grafik Pendapatan',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: report.rows.map((row) {
              final fraction = maxRevenue > 0 ? row.revenue / maxRevenue : 0.0;
              final label = _period == 'monthly'
                  ? row.period.substring(5) // MM
                  : row.period.substring(8); // DD

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: fraction.clamp(0.02, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(fontSize: 9),
                        overflow: TextOverflow.clip,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueTable(RevenueReport report) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detail Per Periode',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(2),
            },
            border: TableBorder(
              horizontalInside: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                children: [
                  _tableCell('Periode', header: true),
                  _tableCell('Pesanan', header: true, center: true),
                  _tableCell('Pendapatan', header: true, right: true),
                ],
              ),
              ...report.rows.map(
                (row) => TableRow(
                  children: [
                    _tableCell(formatDate(row.period)),
                    _tableCell('${row.orders}', center: true),
                    _tableCell(formatRupiah(row.revenue), right: true),
                  ],
                ),
              ),
              TableRow(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                ),
                children: [
                  _tableCell('Total', header: true),
                  _tableCell('${report.totalOrders}',
                      header: true, center: true),
                  _tableCell(formatRupiah(report.totalRevenue),
                      header: true, right: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableCell(String text,
      {bool header = false, bool center = false, bool right = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: right
            ? TextAlign.right
            : (center ? TextAlign.center : TextAlign.left),
        style: TextStyle(
          fontWeight: header ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildEquipmentTab() {
    if (_loadingEquipment) {
      return const LoadingView(message: 'Memuat laporan alat...');
    }
    if (_equipmentError != null) {
      return ErrorView(
        message: _equipmentError!,
        onRetry: _loadEquipmentReport,
      );
    }
    final report = _equipmentReport;
    if (report == null || report.rows.isEmpty) {
      return const EmptyView(
        message: 'Tidak ada data alat dalam rentang tanggal ini.',
        icon: Icons.store_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.attach_money_outlined),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Pendapatan Alat',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        formatRupiah(report.totalRevenue),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  children: [
                    _tableCell('Alat', header: true),
                    _tableCell('Disewa', header: true, center: true),
                    _tableCell('Pendapatan', header: true, right: true),
                  ],
                ),
                ...report.rows.map((row) => TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (row.categoryName != null)
                                Text(
                                  row.categoryName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _tableCell('${row.bookingsCount}', center: true),
                        _tableCell(formatRupiah(row.revenue), right: true),
                      ],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
