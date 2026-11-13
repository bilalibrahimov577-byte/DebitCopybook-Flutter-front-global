// lib/screens/add_debt_screen.dart

import 'package:borc_defteri/models/shared_debt/shared_debt_request.dart';
import 'package:borc_defteri/screens/premium_screen.dart';
import 'package:borc_defteri/services/auth_service.dart';
import 'package:borc_defteri/services/shared_debt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/debt.dart';
import '../models/debt_request.dart';
import '../services/debt_service.dart';
import '../services/recurring_debt_service.dart';

// Borc yaratma növünü müəyyən etmək üçün enum
//enum DebtCreationType { personal, shared }
enum DebtCreationType { personal, shared, recurring }

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
  final _installmentController = TextEditingController();
  int? _selectedDueDay;
  final _recurringDebtService = RecurringDebtService();

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
    try {
      _myDebtId = await _authService.getUserDebtId();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("ID tapılmadı: $e");
    }
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Tarix yoxlaması
  //  if (!_isFlexible && (_selectedYear == null || _selectedMonth == null)) {
    if (_creationType != DebtCreationType.recurring &&
        !_isFlexible && (_selectedYear == null || _selectedMonth == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Zəhmət olmasa, qaytarılma tarixini tam seçin.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // if (_creationType == DebtCreationType.personal) {
      //   await _savePersonalDebt();
      // } else {
      //   await _saveSharedDebt();
      // }

      if (_creationType == DebtCreationType.personal) {
        await _savePersonalDebt();
      } else if (_creationType == DebtCreationType.recurring) {
        await _saveRecurringDebt();
      } else {
        await _saveSharedDebt();
      }
    } catch (e) {
      // Ümumi xəta tutucu (Personal debt üçün)
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
    // Vergül problemini burada da həll edirik
    double amount = double.parse(_debtAmountController.text.replaceAll(',', '.').trim());

    final debtRequest = DebtRequest(
      debtorName: _debtorNameController.text,
      description: _selectedPersonalDebtType,
      debtAmount: amount,
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
        const SnackBar(content: Text("Fərdi borc uğurla yadda saxlanıldı!"),
            backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);


      // AddDebtScreen.dart içində _savePersonalDebt metodu
    } else if (mounted) {
  String errorMsg = result['message'] ?? "";
  print("Backend-den gelen xeta: $errorMsg");

  // Şərti daha geniş qoyuruq ki, mesajın istənilən yerində bu sözlər olsa tutsun
  // if (errorMsg.contains("15") && errorMsg.contains("limit")) {
  // print("Limit xətası aşkar edildi, dialoq açılır...");
  // _showPremiumLimitDialog(errorMsg);
  // }
  if (errorMsg.toLowerCase().contains("limit") || errorMsg.contains("çatmısınız")) {
    print("Limit xətası aşkar edildi, dialoq açılır...");
    _showPremiumLimitDialog(errorMsg);
  } else {
  print("Başqa bir xəta baş verdi.");
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
  );
  }
  }

  }

  double? _parseMoney(String s) => double.tryParse(s.replaceAll(',', '.').trim());

// Qəpiklə hesablayırıq ki, double xətası olmasın
  int? _periodsFor(double total, double inst) {
    final totalC = (total * 100).round();
    final instC = (inst * 100).round();
    if (totalC <= 0 || instC <= 0 || instC > totalC) return null;
    return (totalC + instC - 1) ~/ instC;
  }

  String _centsText(int cents) => cents % 100 == 0
      ? '${cents ~/ 100} ₼'
      : '${(cents / 100).toStringAsFixed(2)} ₼';

  String? _buildInstallmentPreview() {
    final total = _parseMoney(_debtAmountController.text);
    final inst = _parseMoney(_installmentController.text);
    if (total == null || inst == null) return null;
    final periods = _periodsFor(total, inst);
    if (periods == null) return null;
    final totalC = (total * 100).round();
    final instC = (inst * 100).round();
    final lastC = totalC - instC * (periods - 1);
    if (periods == 1) return '1 ödəniş: ${_centsText(totalC)}';
    if (lastC == instC) return '$periods ödəniş × ${_centsText(instC)}';
    return '${periods - 1} ödəniş × ${_centsText(instC)} + sonuncu ${_centsText(lastC)} (cəmi $periods ödəniş)';
  }

  String? _validateInstallment(String? value) {
    if (value == null || value.isEmpty) return 'Bu xana boş buraxıla bilməz';
    final inst = _parseMoney(value);
    if (inst == null || inst <= 0) return 'Məbləğ sıfırdan böyük olmalıdır';
    final total = _parseMoney(_debtAmountController.text);
    if (total != null) {
      if ((inst * 100).round() > (total * 100).round()) {
        return 'Hissə ümumi məbləğdən çox ola bilməz';
      }
      final periods = _periodsFor(total, inst);
      if (periods != null && periods > 360) {
        return 'Ödəniş sayı çox böyükdür (maksimum 360)';
      }
    }
    return null;
  }

  Future<void> _saveRecurringDebt() async {
    final total = _parseMoney(_debtAmountController.text)!;
    final inst = _parseMoney(_installmentController.text)!;

    final result = await _recurringDebtService.create(
      context,
      debtorName: _debtorNameController.text.trim(),
      direction: _selectedPersonalDebtType!,
      totalAmount: total,
      installmentAmount: inst,
      dueDay: _selectedDueDay!,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Təkrarlanan borc uğurla yaradıldı!'),
            backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } else {
      final errorMsg = (result['message'] ?? '').toString();
      if (errorMsg.toLowerCase().contains('limit') || errorMsg.contains('çatmısınız')) {
        _showPremiumLimitDialog(errorMsg);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRecurringFields() {
    final preview = _buildInstallmentPreview();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _installmentController,
          decoration: _inputDecoration('Hər ödənişin məbləği (₼)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d{0,2}'))],
          onChanged: (_) => setState(() {}),
          validator: _validateInstallment,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _selectedDueDay,
          decoration: _inputDecoration('Ödəniş günü (hər ay)'),
          hint: const Text('Ayın neçənci günü?'),
          items: List.generate(
              28, (i) => DropdownMenuItem<int>(value: i + 1, child: Text('${i + 1}'))),
          onChanged: (v) => setState(() => _selectedDueDay = v),
          validator: (v) => v == null ? 'Ödəniş gününü seçin' : null,
        ),
        if (preview != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(preview,
                style: const TextStyle(
                    color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
            'Ödəniş günü gələndə borc sarı olur. Ödənilməsə növbəti gün qırmızı olur.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Future<void> _saveSharedDebt() async {
  // 1. ID yoxlanışı
  if (_counterpartyIdController.text.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text("Qarşı tərəfin ID-si daxil edilməyib"), backgroundColor: Colors.red),
  );
  return;
  }

  try {
  setState(() => _isSaving = true); // Yüklənməni başlat

  // 2. Məbləği təmizləyib parse edirik
  String cleanAmountString = _debtAmountController.text.replaceAll(',', '.').trim();
  double parsedAmount = double.parse(cleanAmountString);

  final request = SharedDebtRequest(
  counterpartyDebtId: _counterpartyIdController.text.trim(),
  debtorName: "",
  debtAmount: parsedAmount,
  description: _selectedPersonalDebtType,
  notes: _notesController.text.isNotEmpty ? _notesController.text : null,
  isFlexibleDueDate: _isFlexible,
  dueYear: _isFlexible ? null : _selectedYear,
  dueMonth: _isFlexible ? null : _selectedMonth,
  );

  // Servisə sorğu göndər
  await _sharedDebtService.createSharedDebtRequest(context, request);

  if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text("Sorğu uğurla göndərildi!"), backgroundColor: Colors.green),
  );
  Navigator.of(context).pop(true);
  }

  } catch (e) {
  // --- ƏSAS XƏTA TUTAN HİSSƏ BURADIR ---
  String errorStr = e.toString();
  debugPrint("SharedDebt Xəta: $errorStr");

  if (mounted) {
  setState(() => _isSaving = false); // Yüklənməni dayandır

  // LİMİT YOXLAMASI: Backend-dən gələn mesajda bu sözlər varsa dialoqu göstər
  // if (errorStr.contains("Limitiniz dolub") || errorStr.contains("maksimal borc limitinə")) {
  // _showPremiumLimitDialog(errorStr);
  // }
  if (errorStr.toLowerCase().contains("limit") || errorStr.contains("çatmısınız")) {
    _showPremiumLimitDialog(errorStr);
  } else {
  // Digər xətalar (ID səhvdir, internet yoxdur və s.) üçün standart dialoq
  showDialog(
  context: context,
  builder: (context) => AlertDialog(
  title: const Text("Xəta Baş Verdi"),
  content: Text(errorStr.replaceFirst("Exception: ", "")), // "Exception: " sözünü təmizləyirik
  actions: [
  TextButton(
  onPressed: () => Navigator.pop(context),
  child: const Text("Bağla"),
  ),
  ],
  ),
  );
  }
  }
  } finally {
  if (mounted) setState(() => _isSaving = false);
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
                    // segments: const <ButtonSegment<DebtCreationType>>[
                    //   ButtonSegment(value: DebtCreationType.personal, label: Text('Fərdi'), icon: Icon(Icons.person)),
                    //   ButtonSegment(value: DebtCreationType.shared, label: Text('Qarşılıqlı'), icon: Icon(Icons.people)),
                    // ],

                    segments: const <ButtonSegment<DebtCreationType>>[
                      ButtonSegment(value: DebtCreationType.personal, label: Text('Fərdi')),
                      ButtonSegment(value: DebtCreationType.shared, label: Text('Qarşılıqlı')),
                      ButtonSegment(value: DebtCreationType.recurring, label: Text('Təkrarlanan')),
                    ],
                    showSelectedIcon: false,

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
               //  if (_creationType == DebtCreationType.shared) ...[
               // //   if (_creationType != DebtCreationType.shared && (value == null || value.isEmpty)) {
               //    TextFormField(
               //      controller: _counterpartyIdController,
               //      decoration: _inputDecoration('Qarşı tərəfin Borc ID-si'),
               //      validator: (value) {
               //        if (_creationType == DebtCreationType.shared) {
               //          if (value == null || value.isEmpty) {
               //            return 'Borc ID-si boş buraxıla bilməz';
               //          }
               //          if (value == _myDebtId) {
               //            return 'Öz ID-nizi daxil edə bilməzsiniz';
               //          }
               //        }
               //        return null;
               //      },
               //    ),
               //    const SizedBox(height: 16),
               //  ],

                // "Şəxsin adı" xanası Fərdi və Təkrarlanan üçün göstərilir
                if (_creationType != DebtCreationType.shared) ...[
                  TextFormField(
                    controller: _debtorNameController,
                    decoration: _inputDecoration('Şəxsin adı'),
                    validator: (value) {
                      if (_creationType != DebtCreationType.shared &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Bu xana boş buraxıla bilməz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _debtAmountController,
                //  decoration: _inputDecoration('Məbləğ (₼)'),
                  decoration: _inputDecoration(_creationType == DebtCreationType.recurring
                      ? 'Ümumi məbləğ (₼)'
                      : 'Məbləğ (₼)'),
                  onChanged: (_) => setState(() {}),

                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  // DÜZƏLİŞ: Regex həm vergül, həm nöqtə qəbul edir
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d{0,2}'))],
                  validator: _validateAmount,
                ),
                // const SizedBox(height: 16),
                // _buildDueDateSection(),
                // const SizedBox(height: 16),

                const SizedBox(height: 16),
                if (_creationType == DebtCreationType.recurring)
                  _buildRecurringFields()
                else
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
    // Vergül yoxlanışı
    String cleanValue = value.replaceAll(',', '.');
    final amount = double.tryParse(cleanValue);
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


  void _showPremiumLimitDialog(String message) {
  showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  title: const Row(
  children: [
  Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
  SizedBox(width: 10),
  Text('Limit Doldu!', style: TextStyle(fontWeight: FontWeight.bold)),
  ],
  ),
  content: Text(message, style: const TextStyle(fontSize: 16)),
  actions: [
  TextButton(
  onPressed: () => Navigator.pop(context),
  child: const Text('Bağla', style: TextStyle(color: Colors.grey, fontSize: 16)),
  ),
  ElevatedButton(
  style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF6A1B9A),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  ),
  onPressed: () {
  Navigator.pop(context);
  // Burada Premium səhifəsinə keçid edəcəyik
  Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const PremiumScreen()),
  );
  },
  child: const Text('Premium-a Bax', style: TextStyle(color: Colors.white, fontSize: 16)),
  ),
  ],
  ),
  );
  }



}