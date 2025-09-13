// lib/screens/debt_details_screen.dart

import 'package:borc_defteri/screens/add_debt_screen.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../models/debt.dart';

import '../services/debt_service.dart';

import '../services/auth_service.dart'; // Əlavə edilib

class DebtDetailsScreen extends StatefulWidget {
  final int debtId;

  const DebtDetailsScreen({super.key, required this.debtId});

  @override
  State<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends State<DebtDetailsScreen> {
  Debt? _debt;

  bool _isLoading = true;

  bool _isProcessing = false;

  final DebtService _debtService = DebtService();

  final AuthService _authService = AuthService(); // Əlavə edilib

  bool _needsRefreshOnExit = false;

  @override
  void initState() {
    super.initState();

    _fetchDebtDetails();
  }

  Future<void> _fetchDebtDetails() async {
    if (!_isLoading) setState(() => _isLoading = true);

    final fetchedDebt = await _debtService.getDebtById(widget.debtId);

    if (mounted) {
      setState(() {
        _debt = fetchedDebt;

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
          title: Text(isPayment ? 'Ödəniş Et' : 'Məbləği Artır',
              style: const TextStyle(color: Color(0xFF6A1B9A))),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Məbləğ (₼)', border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Məbləğ boş ola bilməz';

                final amount = double.tryParse(value);

                if (amount == null) return 'Düzgün rəqəm daxil edin';

                if (isPayment && _debt != null && amount > _debt!.debtAmount)
                  return 'Ödəniş borcdan çox ola bilməz';

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ləğv Et')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final amount = double.parse(controller.text);

                  Navigator.pop(context);

                  _updateDebtAmount(amount: amount, isPayment: isPayment);
                }
              },
              child: const Text('Təsdiqlə',
                  style: TextStyle(color: Color(0xFF6A1B9A))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDebtAmount(
      {required double amount, required bool isPayment}) async {
    setState(() => _isProcessing = true);

    Debt? updatedDebt = isPayment
        ? await _debtService.makePayment(widget.debtId, amount)
        : await _debtService.increaseDebt(widget.debtId, amount);

    if (mounted) {
      if (updatedDebt != null) {
        _needsRefreshOnExit = true;

        if (isPayment && updatedDebt.debtAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Borc tamamilə ödənildi!'),
              backgroundColor: Colors.green)); // Rəngi dəyişildi

          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else {
          setState(() => _debt = updatedDebt);

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Əməliyyat uğurla tamamlandı!'),
              backgroundColor: Colors.green));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Xəta baş verdi!'), backgroundColor: Colors.red));
      }

      setState(() => _isProcessing = false);
    }
  }

  void _performDelete() async {
    setState(() => _isProcessing = true);

    bool success = await _debtService.deleteDebt(widget.debtId);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Xəta baş verdi! Borc silinə bilmədi.')));
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
            TextButton(
                child: const Text('Ləğv Et'),
                onPressed: () => Navigator.of(context).pop()),
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
        backgroundColor: const Color(0xFFF0F2F5), // Açıq boz fon

        appBar: AppBar(
          title: Text(_debt?.debtorName ?? 'Borc Məlumatları',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF6A1B9A),
          leading: BackButton(
            color: Colors.white,
            onPressed: () => Navigator.pop(context, _needsRefreshOnExit),
          ),
          actions: [
            if (_isProcessing)
              const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ))),
            if (!_isLoading && !_isProcessing)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  if (_debt != null) {
                    Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    AddDebtScreen(existingDebt: _debt!)))
                        .then((result) {
                      if (result == true) {
                        _fetchDebtDetails();

                        _needsRefreshOnExit = true;
                      }
                    });
                  }
                },
              ),
            if (!_isLoading && !_isProcessing)
              IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _showDeleteConfirmationDialog),
          ],
        ),

        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
            : _debt == null
                ? const Center(child: Text('Məlumat tapılmadı.'))
                : Padding(
                    padding: const EdgeInsets.all(24.0), // Padding dəyişdirildi

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
// Məbləğ kartı

                        Card(
                          elevation: 4,

                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),

                          color: const Color(0xFF6A1B9A), // Tünd bənövşəyi

                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 24.0, horizontal: 16.0),
                            child: Column(
                              children: [
                                const Text('Qalıq Borc',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 16)),
                                const SizedBox(height: 8),
                                Text(
                                  '${_debt!.debtAmount.toStringAsFixed(2)} ₼',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Expanded(
                          child: ListView(
                            children: [
                              _buildDetailRow(
                                  'Borcalanın Adı:', _debt!.debtorName),
                              _buildDetailRow(
                                  'Açıqlama:', _debt!.description ?? '-'),
                              _buildDetailRow('Yaradılma Tarixi:',
                                  _debt!.createdAt.split('T')[0]),
                              _buildDetailRow(
                                  'Son Ödəmə Tarixi:',
                                  _debt!.isFlexibleDueDate
                                      ? 'Pulum olanda'
                                      : '${_debt!.dueMonth}/${_debt!.dueYear}'),
                              _buildDetailRow('Qeydlər:', _debt!.notes ?? '-'),
                            ],
                          ),
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _showAmountDialog(isPayment: false),
                                icon: const Icon(Icons.add_circle_outline,
                                    color: Colors.white),
                                label: const Text('Məbləği Artır',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _showAmountDialog(isPayment: true),
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.white),
                                label: const Text('Ödəniş Et',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF6A1B9A))),
          // Rəng dəyişdirildi

          const SizedBox(height: 4),

          Text(value,
              style: const TextStyle(fontSize: 18, color: Colors.black87)),
          // Rəng dəyişdirildi

          const Divider(color: Colors.grey),
        ],
      ),
    );
  }
}
