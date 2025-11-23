// lib/screens/add_debt_screen.dart

import 'package:borc_defteri/models/shared_debt/shared_debt_request.dart';
import 'package:borc_defteri/services/auth_service.dart';
import 'package:borc_defteri/services/shared_debt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/debt.dart';
import '../models/debt_request.dart';
import '../services/debt_service.dart';

// Borc yaratma növünü müəyyən etmək üçün enum
enum DebtCreationType { personal, shared }

class AddDebtScreen extends StatefulWidget {
  final Debt? existingDebt;

  const AddDebtScreen({super.key, this.existingDebt});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();

  // Ortaq Controller-lər
  final _debtAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final _debtorNameController = TextEditingController();

  // Qarşılıqlı borc üçün Controller
  final _counterpartyIdController = TextEditingController();

  // Formanın vəziyyətini idarə edən dəyişənlər
  bool _isSaving = false;
  bool _isFlexible = false;
  int? _selectedYear;
  int? _selectedMonth;
  String? _selectedPersonalDebtType; // 'mənim borcum' və ya 'mənə olan borc'

  // Seçilmiş borc yaratma növü
  DebtCreationType _creationType = DebtCreationType.personal;

  // Servislər
  final _debtService = DebtService();
  final _sharedDebtService = SharedDebtService();
  final _authService = AuthService();
  String? _myDebtId; // İstifadəçinin öz Borc ID-si

  bool get _isEditMode => widget.existingDebt != null;

  final List<int> _years = List<int>.generate(5, (index) => DateTime.now().year + index);
  final List<String> _months = [
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'İyun',
    'İyul', 'Avqust', 'Sentyabr', 'Oktyabr', 'Noyabr', 'Dekabr'
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyDebtId();

    if (_isEditMode) {
      // Redaktə zamanı həmişə personal kimi açılır (indiki məntiqə görə)
      _creationType = DebtCreationType.personal;
      final debt = widget.existingDebt!;

      _debtorNameController.text = debt.debtorName;
      _debtAmountController.text = debt.debtAmount.toStringAsFixed(2);
      _notesController.text = debt.notes ?? '';
      _isFlexible = debt.isFlexibleDueDate;
      _selectedYear = debt.dueYear;
      _selectedMonth = debt.dueMonth;

      const validDebtTypes = ['mənim borcum', 'mənə olan borclar'];
      if (validDebtTypes.contains(debt.description)) {
        _selectedPersonalDebtType = debt.description;
      } else {
        _selectedPersonalDebtType = null;
      }
    }
  }

  Future<void> _fetchMyDebtId() async {
    _myDebtId = await _authService.getUserDebtId();
    if (mounted) {
      setState(() {});
    }
  }

  // --- ƏSAS DÜZƏLİŞ BURADADIR ---
  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Tarix yoxlaması
    if (!_isFlexible && (_selectedYear == null || _selectedMonth == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Zəhmət olmasa, qaytarılma tarixini tam seçin.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Burada IF-ELSE işlədiyi üçün EYNİ ANDA yalnız biri işləyəcək.
      // Bu da "2 borc yaranma" problemini həll edir.
      if (_creationType == DebtCreationType.personal) {
        await _savePersonalDebt();
      } else {
        // Shared seçilibsə, personal funksiyası qətiyyən çağırılmır
        await _saveSharedDebt();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _savePersonalDebt() async {
    final debtRequest = DebtRequest(
      debtorName: _debtorNameController.text,
      description: _selectedPersonalDebtType,
      debtAmount: double.parse(_debtAmountController.text),
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      isFlexibleDueDate: _isFlexible,
      dueYear: _isFlexible ? null : _selectedYear,
      dueMonth: _isFlexible ? null : _selectedMonth,
    );

    Map<String, dynamic> result;
    if (_isEditMode) {
      result = await _debtService.updateDebt(context, widget.existingDebt!.id, debtRequest);
    } else {
      result = await _debtService.createDebt(context, debtRequest);
    }

    if (mounted && (result['success'] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fərdi borc uğurla yadda saxlanıldı!"), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Bilinməyən xəta"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveSharedDebt() async {
    // Qarşılıqlı borc üçün ID mütləq olmalıdır
    if (_counterpartyIdController.text.isEmpty) {
      throw Exception("Qarşı tərəfin ID-si daxil edilməyib");
    }

    final request = SharedDebtRequest(
      counterpartyDebtId: _counterpartyIdController.text,
      // Backend qarşı tərəfin adını özü tapır, ona görə bura boş da gedə bilər
      debtorName: "",
      debtAmount: double.parse(_debtAmountController.text),
      description: _selectedPersonalDebtType,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      isFlexibleDueDate: _isFlexible,
      dueYear: _isFlexible ? null : _selectedYear,
      dueMonth: _isFlexible ? null : _selectedMonth,
    );

    // Burada yalnız SharedDebt servisi çağırılır
    await _sharedDebtService.createSharedDebtRequest(context, request);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sorğu uğurla göndərildi!"), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _debtAmountController.dispose();
    _notesController.dispose();
    _debtorNameController.dispose();
    _counterpartyIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Borcu Dəyiş' : 'Yeni Borc Yarat', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Redaktə rejimində növü dəyişməyə icazə vermirik
                if (!_isEditMode) ...[
                  SegmentedButton<DebtCreationType>(
                    segments: const <ButtonSegment<DebtCreationType>>[
                      ButtonSegment(value: DebtCreationType.personal, label: Text('Fərdi'), icon: Icon(Icons.person)),
                      ButtonSegment(value: DebtCreationType.shared, label: Text('Qarşılıqlı'), icon: Icon(Icons.people)),
                    ],
                    selected: {_creationType},
                    onSelectionChanged: (Set<DebtCreationType> newSelection) {
                      setState(() {
                        _creationType = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.grey.shade400,
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: const Color(0xFF6A1B9A),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // "Şəxsin adı" xanasını yalnız "Fərdi" borc növü seçiləndə göstəririk
                if (_creationType == DebtCreationType.personal) ...[
                  TextFormField(
                    controller: _debtorNameController,
                    decoration: _inputDecoration('Şəxsin adı'),
                    validator: (value) {
                      if (_creationType == DebtCreationType.personal && (value == null || value.isEmpty)) {
                        return 'Bu xana boş buraxıla bilməz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                _buildDebtTypeDropdown(),
                const SizedBox(height: 16),

                // ID sahəsi yalnız Shared olanda görünür
                if (_creationType == DebtCreationType.shared) ...[
                  TextFormField(
                    controller: _counterpartyIdController,
                    decoration: _inputDecoration('Qarşı tərəfin Borc ID-si'),
                    validator: (value) {
                      if (_creationType == DebtCreationType.shared) {
                        if (value == null || value.isEmpty) {
                          return 'Borc ID-si boş buraxıla bilməz';
                        }
                        if (value == _myDebtId) {
                          return 'Öz ID-nizi daxil edə bilməzsiniz';
                        }
                        // ID formatı yoxlanışı (lazımdırsa aktivləşdir)
                        /*
                        if (!RegExp(r'^\d{2}-\d{2}$').hasMatch(value)) {
                          return 'ID formatı düzgün deyil (Məs: 12-34)';
                        }
                        */
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _debtAmountController,
                  decoration: _inputDecoration('Məbləğ (₼)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  validator: _validateAmount,
                ),
                const SizedBox(height: 16),
                _buildDueDateSection(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: _inputDecoration('Qeydlər'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedPersonalDebtType,
      decoration: _inputDecoration('Borcun növü'),
      hint: const Text('Növünü seçin...'),
      items: const [
        DropdownMenuItem(value: 'mənim borcum', child: Text('Mənim Borcum')),
        DropdownMenuItem(value: 'mənə olan borclar', child: Text('Mənə Olan Borclar')),
      ],
      onChanged: (String? newValue) {
        setState(() {
          _selectedPersonalDebtType = newValue;
        });
      },
      validator: (value) => value == null ? 'Zəhmət olmasa borcun növünü seçin' : null,
    );
  }

  Widget _buildDueDateSection() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Qaytarılma vaxtı qeyri-müəyyəndir', style: TextStyle(color: Color(0xFF6A1B9A))),
          value: _isFlexible,
          onChanged: (bool? value) => setState(() {
            _isFlexible = value ?? false;
            if (_isFlexible) {
              _selectedYear = null;
              _selectedMonth = null;
            }
          }),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
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
      ],
    );
  }

  Widget _buildSaveButton() {
    return _isSaving
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
        : ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6A1B9A),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _saveDebt,
      child: Text(
        _isEditMode ? 'Dəyişiklikləri Yadda Saxla' : 'Yadda Saxla',
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) return 'Bu xana boş buraxıla bilməz';
    final amount = double.tryParse(value);
    if (amount == null) return 'Zəhmət olmasa düzgün rəqəm daxil edin';
    if (!_isEditMode && amount <= 0) return 'Məbləğ sıfırdan böyük olmalıdır';
    return null;
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