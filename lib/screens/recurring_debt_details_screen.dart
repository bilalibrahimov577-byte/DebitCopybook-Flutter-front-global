import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/recurring_debt.dart';
import '../models/recurring_debt_payment.dart';
import '../services/recurring_debt_service.dart';

class RecurringDebtDetailsScreen extends StatefulWidget {
  final RecurringDebt debt;

  const RecurringDebtDetailsScreen({super.key, required this.debt});

  @override
  State<RecurringDebtDetailsScreen> createState() =>
      _RecurringDebtDetailsScreenState();
}

class _RecurringDebtDetailsScreenState
    extends State<RecurringDebtDetailsScreen> {
  static const Color _purple = Color(0xFF6A1B9A);

  final RecurringDebtService _service = RecurringDebtService();
  late RecurringDebt _debt;
  List<RecurringDebtPayment> _payments = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _debt = widget.debt;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getById(context, _debt.id),
        _service.getPayments(context, _debt.id),
      ]);
      if (mounted) {
        setState(() {
          _debt = results[0] as RecurringDebt;
          _payments = results[1] as List<RecurringDebtPayment>;
        });
      }
    } catch (e) {
      debugPrint('Təkrarlanan borc detalı xətası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Məlumatları yükləmək alınmadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 50 -> "50", 50.5 -> "50.50" (dialoqda doldurmaq üçün)
  String _plain(double v) {
    final cents = (v * 100).round();
    return cents % 100 == 0
        ? (cents ~/ 100).toString()
        : (cents / 100).toStringAsFixed(2);
  }

  void _showPayDialog() {
    final suggested =
    _debt.amountDueNow > 0 ? _debt.amountDueNow : _debt.nextPaymentAmount;
    final controller = TextEditingController(text: _plain(suggested));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ödəniş Et'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d{0,2}'))
                ],
                decoration: InputDecoration(
                  labelText: 'Məbləğ (₼)',
                  helperText: 'Qalıq borc: ${formatAzn(_debt.remainingAmount)}',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Məbləğ boş ola bilməz';
                  }
                  final amount = double.tryParse(value.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) {
                    return 'Məbləğ 0-dan böyük olmalıdır';
                  }
                  if ((amount * 100).round() >
                      (_debt.remainingAmount * 100).round()) {
                    return 'Ödəniş qalan borcdan çox ola bilməz';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ləğv Et')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final amount =
                double.parse(controller.text.replaceAll(',', '.'));
                Navigator.pop(dialogContext);
                _pay(amount);
              }
            },
            child: const Text('Təsdiqlə'),
          ),
        ],
      ),
    );
  }

  Future<void> _pay(double amount) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _service.pay(context, _debt.id, amount);
      if (!mounted) return;
      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Əməliyyat tamamlandı'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) {
        _changed = true;
        await _load();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Silməni təsdiqlə'),
        content: const Text('Bu borcu və ödəniş tarixçəsini silməyə əminsinizmi?'),
        actions: [
          TextButton(
              child: const Text('Ləğv Et'),
              onPressed: () => Navigator.pop(dialogContext)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Bəli, Sil'),
            onPressed: () {
              Navigator.pop(dialogContext);
              _performDelete();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    setState(() => _isProcessing = true);
    final success = await _service.delete(context, _debt.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xəta baş verdi! Borc silinə bilmədi.')),
      );
    }
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
          title: Text(_debt.debtorName,
              style: const TextStyle(color: Colors.white)),
          backgroundColor: _purple,
          leading: BackButton(
              color: Colors.white,
              onPressed: () => Navigator.pop(context, _changed)),
          actions: [
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3)),
              )
            else
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Sil',
                onPressed: _isLoading ? null : _confirmDelete,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : RefreshIndicator(
          color: _purple,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildHeader(),
              _buildStatusCard(),
              _buildInfoCard(),
              _buildPayButton(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Ödəniş Tarixçəsi',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54)),
              ),
              _buildPayments(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: _purple,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Text('Qalıq Borc (Təkrarlanan)',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                Text(formatAzn(_debt.remainingAmount),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    'Ödənilib: ${formatAzn(_debt.paidAmount)} / ${formatAzn(_debt.totalAmount)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color color;
    IconData icon;
    String title;
    String? subtitle;

    if (_debt.isCompleted) {
      color = Colors.grey.shade300;
      icon = Icons.check_circle;
      title = 'Borc tam ödənilib';
      subtitle =
      'Ödənilmiş borclar müəyyən müddət keçdikdən sonra avtomatik silinir.';
    } else if (_debt.isOverdue) {
      color = Colors.red.shade100;
      icon = Icons.warning_amber_rounded;
      title = 'Gecikmə var. İndi ödənməli: ${formatAzn(_debt.amountDueNow)}';
      if (_debt.overdueAmount > 0 && _debt.overdueAmount < _debt.amountDueNow) {
        subtitle =
        'Keçən aylardan gecikmə: ${formatAzn(_debt.overdueAmount)}';
      }
    } else if (_debt.isDueToday) {
      color = Colors.amber.shade100;
      icon = Icons.schedule;
      title = 'Bu gün ödəniş günüdür: ${formatAzn(_debt.amountDueNow)}';
    } else {
      color = Colors.white;
      icon = Icons.event_available;
      title = 'Növbəti ödəniş: ${formatAzn(_debt.nextPaymentAmount)}';
      if (_debt.nextDueDate != null) {
        subtitle = DateFormat('dd.MM.yyyy').format(_debt.nextDueDate!);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: color,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: Colors.black54, size: 30),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: subtitle != null ? Text(subtitle) : null,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final notes = _debt.notes;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline, color: _purple),
              title: const Text('Borcun növü',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_debt.direction),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.payments_outlined, color: Colors.green),
              title: const Text('Hər ödəniş',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${formatAzn(_debt.installmentAmount)} · hər ayın ${_debt.dueDay}. günü'),
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.note, color: Colors.orange),
                title: const Text('Qeyd',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(notes),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: (_isProcessing || _debt.isCompleted) ? null : _showPayDialog,
        icon: const Icon(Icons.remove_circle_outline),
        label: const Text('Ödəniş Et'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildPayments() {
    if (_payments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Hələ ödəniş edilməyib.')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        final date = p.paidAt != null
            ? DateFormat('dd.MM.yyyy, HH:mm').format(p.paidAt!)
            : '';
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const Icon(Icons.payment, color: Colors.green),
            title: Text('Ödəniş: ${formatAzn(p.amount)}'),
            subtitle: Text('Qalıq: ${formatAzn(p.remainingAfter)} · $date'),
          ),
        );
      },
    );
  }
}