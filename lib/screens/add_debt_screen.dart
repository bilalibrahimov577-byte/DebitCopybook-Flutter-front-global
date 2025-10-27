// lib/screens/add_debt_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/debt.dart';
import '../models/debt_request.dart';
import '../services/debt_service.dart';

class AddDebtScreen extends StatefulWidget {
  final Debt? existingDebt;

  const AddDebtScreen({super.key, this.existingDebt});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _debtorNameController = TextEditingController();
  final _debtAmountController = TextEditingController();
  final _notesController = TextEditingController();

  // === DƏYİŞDİRİLDİ: Açıqlama controller-i ləğv edildi ===
  // final _descriptionController = TextEditingController();

  // === YENİ: Seçilmiş borc növünü saxlamaq üçün dəyişən ===
  String? _selectedDebtType;

  // === YENİ: Backend-ə göndəriləcək dəqiq mətnləri saxlamaq üçün sabit dəyərlər ===
  final String myDebtValue = 'mənim borcum';
  final String debtToMeValue = 'mənə olan borclar';

  bool _isSaving = false;
  bool _isFlexible = false;
  int? _selectedYear;
  int? _selectedMonth;

  bool get _isEditMode => widget.existingDebt != null;

  final List<int> _years = List<int>.generate(5, (index) => DateTime.now().year + index);
  final List<String> _months = [
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'İyun',
    'İyul', 'Avqust', 'Sentyabr', 'Oktyabr', 'Noyabr', 'Dekabr'
  ];

  @override
  void initState() {
    super.initState();

    if (_isEditMode) {
      final debt = widget.existingDebt!;
      _debtorNameController.text = debt.debtorName;
      _debtAmountController.text = debt.debtAmount.toStringAsFixed(2);
      _notesController.text = debt.notes ?? '';
      _isFlexible = debt.isFlexibleDueDate;
      _selectedYear = debt.dueYear;
      _selectedMonth = debt.dueMonth;

      // === DƏYİŞDİRİLDİ: Redaktə rejimində description-u seçilmiş növə təyin edirik ===
      // _descriptionController.text = debt.description ?? '';

      // Əgər köhnə borcun description-u bizim dəyərlərdən birinə uyğundursa,
      // Dropdown-da həmin dəyəri seçilmiş göstər.
      if (debt.description == myDebtValue || debt.description == debtToMeValue) {
        _selectedDebtType = debt.description;
      }
    }
  }

  Future<void> _saveDebt() async {
    if (_formKey.currentState!.validate()) {
      if (!_isFlexible && (_selectedYear == null || _selectedMonth == null)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Zəhmət olmasa, qaytarılma tarixini tam seçin.')));
        return;
      }

      setState(() => _isSaving = true);

      final debtService = DebtService();

      // === DƏYİŞDİRİLDİ: DebtRequest yaradanda description-u controller-dən yox, _selectedDebtType-dan alırıq ===
      final debtRequest = DebtRequest(
        debtorName: _debtorNameController.text,
        description: _selectedDebtType, // Məcburi seçim olduğu üçün artıq boş ola bilməz.
        debtAmount: double.parse(_debtAmountController.text),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        isFlexibleDueDate: _isFlexible,
        dueYear: _isFlexible ? null : _selectedYear,
        dueMonth: _isFlexible ? null : _selectedMonth,
      );

      try {
        Map<String, dynamic> result;
        if (_isEditMode) {
          result = await debtService.updateDebt(context, widget.existingDebt!.id, debtRequest);
        } else {
          result = await debtService.createDebt(context, debtRequest);
        }

        final success = result['success'];
        final message = result['message'];

        if (!mounted) return;

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Gözlənilməyən xəta baş verdi.'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _debtorNameController.dispose();
    _debtAmountController.dispose();
    _notesController.dispose();
    // === DƏYİŞDİRİLDİ: _descriptionController ləğv edildi ===
    // _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Borcu Dəyiş' : 'Yeni Borc Əlavə Et',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _debtorNameController,
                  decoration: _inputDecoration('Şəxsin adı'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Bu xana boş buraxıla bilməz';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // === YENİ: Açıqlama TextField-i DropdownButtonFormField ilə əvəz edildi ===
                DropdownButtonFormField<String>(
                  value: _selectedDebtType,
                  decoration: _inputDecoration('Borcun növü'),
                  hint: const Text('Növünü seçin...'), // value null olanda görünəcək
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: myDebtValue, child: Text('Mənim Borcum')),
                    DropdownMenuItem(value: debtToMeValue, child: Text('Mənə Olan Borc')),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDebtType = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Zəhmət olmasa borcun növünü seçin';
                    }
                    return null;
                  },
                ),
                // =========================================================================

                const SizedBox(height: 16),
                TextFormField(
                  controller: _debtAmountController,
                  decoration: _inputDecoration('Məbləğ (₼)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Bu xana boş buraxıla bilməz';
                    final amount = double.tryParse(value);
                    if (amount == null) return 'Zəhmət olmasa düzgün rəqəm daxil edin';
                    if (!_isEditMode && amount <= 0) return 'Məbləğ sıfırdan böyük olmalıdır';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Qaytarılma vaxtı qeyri-müəyyəndir ("Pulum olanda")',
                      style: TextStyle(color: Color(0xFF6A1B9A))),
                  value: _isFlexible,
                  onChanged: (bool? value) => setState(() {
                    _isFlexible = value ?? false;
                    if (_isFlexible) {
                      _selectedYear = null;
                      _selectedMonth = null;
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading, // Checkbox-ı sola çəkir
                  contentPadding: EdgeInsets.zero, // Əlavə boşluqları silir
                ),
                if (!_isFlexible)
                  Row(
                    children: [
                      Expanded(
                          child: DropdownButtonFormField<int>(
                              value: _selectedYear,
                              hint: const Text('İli seçin'),
                              decoration: _inputDecoration(null),
                              items: _years.map((y) => DropdownMenuItem<int>(value: y, child: Text(y.toString()))).toList(),
                              onChanged: (v) => setState(() => _selectedYear = v))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: DropdownButtonFormField<int>(
                              value: _selectedMonth,
                              hint: const Text('Ayı seçin'),
                              decoration: _inputDecoration(null),
                              items: List.generate(12, (i) => DropdownMenuItem<int>(value: i + 1, child: Text(_months[i]))),
                              onChanged: (v) => setState(() => _selectedMonth = v))),
                    ],
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: _inputDecoration('Qeydlər'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                _isSaving
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
                    : Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Ləğv et', style: TextStyle(fontSize: 16, color: Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A1B9A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _saveDebt,
                        child: Text(
                          _isEditMode ? 'Yadda Saxla' : 'Yadda Saxla',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Color(0xFF6A1B9A)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2.0),
      ),
    );
  }
}