import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_debt.dart';
import '../services/recurring_debt_service.dart';
import 'recurring_debt_details_screen.dart';

// Gələcəkdə sadə və qarşılıqlı ödənilmiş borclar da bura əlavə olunacaq
class CompletedDebtsScreen extends StatefulWidget {
  const CompletedDebtsScreen({super.key});

  @override
  State<CompletedDebtsScreen> createState() => _CompletedDebtsScreenState();
}

class _CompletedDebtsScreenState extends State<CompletedDebtsScreen> {
  static const Color _purple = Color(0xFF6A1B9A);
  static const String _myDebt = 'mənim borcum';
  static const String _debtToMe = 'mənə olan borclar';

  final RecurringDebtService _service = RecurringDebtService();
  List<RecurringDebt> _all = [];
  bool _isLoading = true;
  bool _failed = false;
  bool _showMyDebts = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final list = await _service.getAll(context);
      final completed = list.where((d) => d.isCompleted).toList();
      // ən son bağlanan yuxarıda
      completed.sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt));
      if (mounted) setState(() => _all = completed);
    } catch (e) {
      debugPrint('Ödənilmiş borclar xətası: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _total(String direction) => _all
      .where((d) => d.direction == direction)
      .fold(0.0, (sum, d) => sum + d.totalAmount);

  Future<void> _open(RecurringDebt debt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => RecurringDebtDetailsScreen(debt: debt)),
    );
    if (result == true) {
      _changed = true;
      _load();
    }
  }

  Widget _totalCard(String title, double total, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? _purple : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _purple, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 6),
              Text(formatAzn(total),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : _purple)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debtCard(RecurringDebt debt) {
    final closed = debt.completedAt != null
        ? 'Bağlanıb: ${DateFormat('dd.MM.yyyy').format(debt.completedAt!.toLocal())}'
        : 'Tam ödənilib';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        color: Colors.grey.shade200,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(debt),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                      color: Colors.teal.shade400,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(formatAzn(debt.totalAmount),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debt.debtorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF333333))),
                      const SizedBox(height: 4),
                      Text('${debt.direction} · təkrarlanan',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(closed,
                          style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.teal.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }
    if (_failed) {
      return const Center(child: Text('Məlumatlar yüklənmədi. Yeniləyin.'));
    }
    final list =
    _all.where((d) => d.direction == (_showMyDebts ? _myDebt : _debtToMe)).toList();
    if (list.isEmpty) {
      return const Center(
        child: Text('Ödənilmiş borc yoxdur',
            style: TextStyle(color: Colors.black54, fontSize: 16)),
      );
    }
    return RefreshIndicator(
      color: _purple,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, i) => _debtCard(list[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: const Text('Ödənilmiş borclar',
              style: TextStyle(color: Colors.white)),
          backgroundColor: _purple,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  _totalCard('Mənim borclarım', _total(_myDebt), _showMyDebts,
                          () => setState(() => _showMyDebts = true)),
                  const SizedBox(width: 12),
                  _totalCard('Mənə olan borclar', _total(_debtToMe),
                      !_showMyDebts, () => setState(() => _showMyDebts = false)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                  'Ödənilmiş borclar müəyyən müddət keçdikdən sonra avtomatik silinir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.black54)),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}