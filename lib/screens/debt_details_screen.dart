import 'package:borc_defteri/screens/add_debt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // YENİ: Tarixləri formatlamaq üçün
import '../models/debt.dart';
import '../models/debt_history.dart'; // YENİ: Tarixçə modeli
import '../services/debt_service.dart';
import '../services/auth_service.dart';

class DebtDetailsScreen extends StatefulWidget {
  final int debtId;
  const DebtDetailsScreen({super.key, required this.debtId});

  @override
  State<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends State<DebtDetailsScreen> {
  Debt? _debt;
  List<DebtHistory> _history = []; // YENİ: Tarixçə siyahısı
  bool _isLoading = true;
  bool _isProcessing = false;
  final DebtService _debtService = DebtService();
  bool _needsRefreshOnExit = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // YENİ: Həm borc detallarını, həm də tarixçəni eyni anda çəkir
  Future<void> _fetchData() async {
    if (!_isLoading) setState(() => _isLoading = true);

    // İki sorğunu eyni anda göndəririk ki, vaxta qənaət edək
    final results = await Future.wait([
      _debtService.getDebtById(context,widget.debtId),
      _debtService.getDebtHistory(context,widget.debtId),
    ]);

    if (mounted) {
      setState(() {
        _debt = results[0] as Debt?;
        _history = results[1] as List<DebtHistory>;
        _isLoading = false;
      });
    }
  }

  void _showAmountDialog({required bool isPayment}) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isPayment ? 'Ödəniş Et' : 'Məbləği Artır', style: const TextStyle(color: Color(0xFF6A1B9A))),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              decoration: const InputDecoration(labelText: 'Məbləğ (₼)', border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Məbləğ boş ola bilməz';
                final amount = double.tryParse(value);
                if (amount == null) return 'Düzgün rəqəm daxil edin';
                if (amount <= 0) return 'Məbləğ 0-dan böyük olmalıdır';
                if (isPayment && _debt != null && amount > _debt!.debtAmount) return 'Ödəniş borcdan çox ola bilməz';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv Et')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final amount = double.parse(controller.text);
                  Navigator.pop(context);
                  _processTransaction(amount: amount, isPayment: isPayment);
                }
              },
              child: const Text('Təsdiqlə', style: TextStyle(color: Color(0xFF6A1B9A))),
            ),
          ],
        );
      },
    );
  }

  // YENİLƏNDİ: Yeni cavab formatı ilə işləyir
  Future<void> _processTransaction({required double amount, required bool isPayment}) async {
    setState(() => _isProcessing = true);

    final result = isPayment
        ? await _debtService.makePayment(context,widget.debtId, amount)
        : await _debtService.increaseDebt(context,widget.debtId, amount);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Bilinməyən cavab'),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ));

      if (result['success']) {
        _needsRefreshOnExit = true;

        // Ödənişdən sonra borc silinibsə (backend-dəki məntiqə görə),
        // sadəcə ana səhifəyə qayıdırıq.
        if (isPayment) {
          final currentDebt = await _debtService.getDebtById(context,widget.debtId);
          if(currentDebt == null) {
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.of(context).pop(true);
            });
            return;
          }
        }

        // Əks halda, həm detalları, həm də tarixçəni yeniləyirik
        await _fetchData();
      }

      setState(() => _isProcessing = false);
    }
  }

  // Bu metodlarda dəyişiklik yoxdur
  void _performDelete() async {
    setState(() => _isProcessing = true);
    bool success = await _debtService.deleteDebt(context,widget.debtId);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xəta baş verdi! Borc silinə bilmədi.')));
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Silməni təsdiqlə'),
          content: const Text('Bu borcu silməyə əminsinizmi?'),
          actions: <Widget>[
            TextButton(child: const Text('Ləğv Et'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Bəli, Sil'),
              onPressed: () {
                Navigator.of(context).pop();
                _performDelete();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _needsRefreshOnExit);
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: Text(_debt?.debtorName ?? 'Borc Məlumatları', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF6A1B9A),
          leading: BackButton(color: Colors.white, onPressed: () => Navigator.pop(context, _needsRefreshOnExit)),
          actions: [
            if (_isProcessing)
              const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))),
            if (!_isLoading && !_isProcessing)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  if (_debt != null) {
                    Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => AddDebtScreen(existingDebt: _debt!)))
                        .then((result) {
                      if (result == true) {
                        _fetchData(); // _fetchDebtDetails -> _fetchData
                        _needsRefreshOnExit = true;
                      }
                    });
                  }
                },
              ),
            if (!_isLoading && !_isProcessing)
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _showDeleteConfirmationDialog),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
            : _debt == null
            ? const Center(child: Text('Məlumat tapılmadı.'))
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: const Color(0xFF6A1B9A),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                      child: Column(
                        children: [
                          const Text('Qalıq Borc', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('${_debt!.debtAmount.toStringAsFixed(2)} ₼', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _showAmountDialog(isPayment: false),
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                          label: const Text('Məbləği Artır', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _showAmountDialog(isPayment: true),
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                          label: const Text('Ödəniş Et', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("Əməliyyat Tarixçəsi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
            // YENİ: Tarixçə siyahısı
            Expanded(
              child: _history.isEmpty
                  ? const Center(child: Text("Heç bir əməliyyat tapılmadı."))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final historyItem = _history[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    child: ListTile(
                      leading: _getHistoryIcon(historyItem.eventType),
                      title: Text(historyItem.description),
                      subtitle: Text(DateFormat('dd.MM.yyyy, HH:mm').format(historyItem.eventDate.toLocal())),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // YENİ: Tarixçə növünə görə ikon qaytaran köməkçi funksiya
  Widget _getHistoryIcon(String eventType) {
    switch (eventType) {
      case 'CREATED':
        return const Icon(Icons.add_comment, color: Colors.blue);
      case 'UPDATED':
        return const Icon(Icons.edit_note, color: Colors.orange);
      case 'PAYMENT':
        return const Icon(Icons.payment, color: Colors.green);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

// Bu metod artıq lazım deyil, onun yerinə tarixçə istifadə olunur
// Widget _buildDetailRow(String title, String value) { ... }
}