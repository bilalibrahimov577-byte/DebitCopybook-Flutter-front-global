// lib/screens/debt_details_screen.dart

import 'package:borc_defteri/models/shared_debt/update_proposal_request.dart';
import 'package:borc_defteri/models/unified_debt_item.dart';
import 'package:borc_defteri/services/shared_debt_service.dart';
import 'package:borc_defteri/services/auth_service.dart'; // AuthService əlavə olundu
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/debt.dart';
import '../models/debt_history.dart';

import '../models/shared_debt/shared_debt.dart';
import '../services/debt_service.dart';
import 'add_debt_screen.dart';

class DebtDetailsScreen extends StatefulWidget {
  final UnifiedDebtItem item;

  const DebtDetailsScreen({super.key, required this.item});

  @override
  State<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends State<DebtDetailsScreen> {
  late UnifiedDebtItem _currentItem;
  List<DebtHistory> _history = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  final DebtService _debtService = DebtService();
  final SharedDebtService _sharedDebtService = SharedDebtService();
  final AuthService _authService = AuthService(); // Auth Service əlavə etdik

  bool _needsRefreshOnExit = false;
  String? _currentUserId; // Öz ID-mizi saxlamaq üçün

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Öz ID-mizi götürürük
      _currentUserId = await _authService.getUserUniqueId();

      final debtId = _currentItem.type == DebtType.personal
          ? (_currentItem.data as Debt).id
          : (_currentItem.data as SharedDebt).id;

      _history = await _debtService.getDebtHistory(context, debtId);
    } catch (e) {
      if (mounted) {
        debugPrint("Tarixçə xətası: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAmountDialog({required bool isPayment, required bool isPersonal}) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final currentAmount = isPersonal
        ? (_currentItem.data as Debt).debtAmount
        : (_currentItem.data as SharedDebt).debtAmount;

    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: Text(isPersonal
            ? (isPayment ? 'Ödəniş Et' : 'Məbləği Artır')
            : (isPayment ? 'Ödəniş Təklif Et' : 'Məbləği Artırmaq üçün Təklif')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            decoration: const InputDecoration(
                labelText: 'Məbləğ (₼)', border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Məbləğ boş ola bilməz';
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0)
                return 'Məbləğ 0-dan böyük olmalıdır';
              if (isPersonal && isPayment && amount > currentAmount)
                return 'Ödəniş borcdan çox ola bilməz';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ləğv Et')),
          ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final amount = double.parse(controller.text);
                  Navigator.pop(context);

                  if (isPersonal) {
                    _processPersonalDebtTransaction(
                        amount: amount, isPayment: isPayment);
                  } else {
                    double newAmount = isPayment
                        ? (currentAmount - amount)
                        : (currentAmount + amount);
                    if (newAmount < 0) newAmount = 0;
                    _sendUpdateProposal(proposedAmount: newAmount);
                  }
                }
              },
              child: Text(isPersonal ? 'Təsdiqlə' : 'Təklif Göndər')),
        ],
      );
    });
  }

  Future<void> _processPersonalDebtTransaction(
      {required double amount, required bool isPayment}) async {
    setState(() => _isProcessing = true);
    final debtId = (_currentItem.data as Debt).id;
    try {
      final result = isPayment
          ? await _debtService.makePayment(context, debtId, amount)
          : await _debtService.increaseDebt(context, debtId, amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Əməliyyat tamamlandı'),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ));
        if (result['success']) {
          _needsRefreshOnExit = true;
          final updatedDebt = await _debtService.getDebtById(context, debtId);
          if (updatedDebt == null) {
            Navigator.pop(context, true);
          } else {
            setState(() {
              _currentItem = UnifiedDebtItem.fromPersonalDebt(updatedDebt);
            });
            await _fetchData();
          }
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Xəta: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _performDelete() async {
    setState(() => _isProcessing = true);
    final debtId = (_currentItem.data as Debt).id;
    final success = await _debtService.deleteDebt(context, debtId);
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
                    }),
              ]);
        });
  }

  void _showDeleteProposalDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Silmə Təklifi'),
            content: const Text(
                'Bu borcun ləğv edilməsi üçün qarşı tərəfə təklif göndərməyə əminsinizmi?'),
            actions: <Widget>[
              TextButton(
                  child: const Text('Ləğv Et'),
                  onPressed: () => Navigator.of(context).pop()),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Bəli, Təklif Göndər'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _sendUpdateProposal(proposedAmount: 0);
                },
              ),
            ],
          );
        });
  }

  void _showProposeUpdateDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Dəyişiklik Təklif Et"),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      decoration: InputDecoration(
                          labelText: "Yeni məbləğ (istəyə bağlı)",
                          hintText: (_currentItem.data as SharedDebt)
                              .debtAmount
                              .toStringAsFixed(2)),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final amount = double.tryParse(value);
                          if (amount == null)
                            return 'Düzgün məbləğ daxil edin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                          labelText: "Yeni qeydlər (istəyə bağlı)",
                          hintText:
                          (_currentItem.data as SharedDebt).notes ?? ""),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Ləğv Et")),
              ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      if (amountController.text.isEmpty &&
                          notesController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                Text("Ən az bir sahəni doldurun!")));
                        return;
                      }
                      Navigator.pop(context);
                      _sendUpdateProposal(
                        proposedAmount: amountController.text.isNotEmpty
                            ? double.parse(amountController.text)
                            : null,
                        proposedNotes: notesController.text.isNotEmpty
                            ? notesController.text
                            : null,
                      );
                    }
                  },
                  child: const Text("Təklif Göndər")),
            ],
          );
        });
  }

  Future<void> _sendUpdateProposal(
      {double? proposedAmount, String? proposedNotes}) async {
    setState(() => _isProcessing = true);
    final debtId = (_currentItem.data as SharedDebt).id;
    try {
      final request = UpdateProposalRequest(
          proposedAmount: proposedAmount, proposedNotes: proposedNotes);
      await _sharedDebtService.createUpdateProposal(context, debtId, request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Təklif uğurla göndərildi!"),
            backgroundColor: Colors.green));
        _needsRefreshOnExit = true;
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Xəta baş verdi: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = _currentItem.type == DebtType.personal;
    final debtData = _currentItem.data;

    String displayName = "Yüklənir...";
    double debtAmount = 0.0;

    if (isPersonal) {
      final debt = debtData as Debt;
      displayName = debt.debtorName;
      debtAmount = debt.debtAmount;
    } else {
      final debt = debtData as SharedDebt;
      debtAmount = debt.debtAmount;

      // --- AD MƏNTİQİNİN DÜZƏLDİLMƏSİ ---
      if (_currentUserId != null) {
        // Əgər mən borcu yaradanamsa -> Qarşı tərəfin adını göstər
        if (debt.user.id.toString() == _currentUserId) {
          displayName = debt.counterpartyUser.name;
        }
        // Əgər borc mənə gəlibsə -> Yaradanın adını göstər
        else {
          displayName = debt.user.name;
        }
      } else {
        // ID hələ yüklənməyibsə (nadir hal), default olaraq counterparty-ni göstər
        displayName = debt.counterpartyUser.name;
      }
      // ----------------------------------
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _needsRefreshOnExit);
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: Text(displayName, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF6A1B9A),
          leading: BackButton(
              color: Colors.white,
              onPressed: () => Navigator.pop(context, _needsRefreshOnExit)),
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
            if (!_isLoading && !_isProcessing) ...[
              if (isPersonal)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Redaktə Et',
                  onPressed: () {
                    Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddDebtScreen(
                                existingDebt: debtData as Debt))).then(
                            (result) async {
                          if (result == true) {
                            _needsRefreshOnExit = true;
                            await _fetchData();
                          }
                        });
                  },
                ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Sil',
                onPressed: () {
                  if (isPersonal) {
                    _showDeleteConfirmationDialog();
                  } else {
                    _showDeleteProposalDialog();
                  }
                },
              ),
            ]
          ],
        ),
        body: _isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
            : Column(children: [
          _buildHeader(debtAmount, isPersonal, debtData, displayName), // DisplayName-i bura da ötürürük

          _buildInfoSection(isPersonal, debtData),

          _buildActionButtons(isPersonal),
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Əməliyyat Tarixçəsi",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54))),
          ),
          _buildHistoryList(),
        ]),
      ),
    );
  }

  Widget _buildInfoSection(bool isPersonal, dynamic debtData) {
    String? notes;
    String? createdAtStr;
    String dueDateString = "Müddətsiz / İmkan olanda";

    if (isPersonal) {
      final debt = debtData as Debt;
      notes = debt.notes;

      if (debt.createdAt is DateTime) {
        createdAtStr = DateFormat('dd.MM.yyyy').format(debt.createdAt as DateTime);
      } else if (debt.createdAt is String) {
        createdAtStr = debt.createdAt as String;
      } else {
        createdAtStr = null;
      }

      if (!debt.isFlexibleDueDate && debt.dueYear != null && debt.dueMonth != null) {
        dueDateString = "${debt.dueMonth}/${debt.dueYear}";
      }
    } else {
      final debt = debtData as SharedDebt;
      notes = debt.notes;
      createdAtStr = debt.createdAt;

      if (!debt.isFlexibleDueDate && debt.dueYear != null && debt.dueMonth != null) {
        dueDateString = "${debt.dueMonth}/${debt.dueYear}";
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              if (createdAtStr != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: const Text("Yaradılma Tarixi",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(createdAtStr),
                ),

              ListTile(
                dense: true,
                leading: const Icon(Icons.event_busy, color: Colors.redAccent),
                title: const Text("Son Ödəniş Tarixi",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(dueDateString),
              ),

              if (notes != null && notes.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.note, color: Colors.orange),
                  title: const Text("Qeyd",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(notes),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Header-ə displayName parametrini də əlavə etdim ki, kartın içində də düzgün ad görünsün
  Widget _buildHeader(double amount, bool isPersonal, dynamic debtData, String displayName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isPersonal ? const Color(0xFF6A1B9A) : Colors.blue.shade700,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            children: [
              Text(
                  isPersonal
                      ? 'Qalıq Borc (Şəxsi)'
                      : 'Qalıq Borc (Qarşılıqlı)',
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text('${amount.toStringAsFixed(2)} ₼',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold)),
              if (!isPersonal) ...[
                const SizedBox(height: 10),
                Text(
                  // Artıq hesablanmış düzgün adı göstəririk
                    "Tərəf müqabili: $displayName",
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isPersonal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () => _showAmountDialog(
                isPayment: false, isPersonal: isPersonal),
            icon: const Icon(Icons.add_circle_outline),
            label:
            Text(isPersonal ? 'Məbləği Artır' : 'Artırmaq üçün Təklif'),
            style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () =>
                _showAmountDialog(isPayment: true, isPersonal: isPersonal),
            icon: const Icon(Icons.remove_circle_outline),
            label: Text(isPersonal ? 'Ödəniş Et' : 'Ödəniş Təklif Et'),
            style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
          ),
        ),
      ]),
    );
  }

  Widget _buildHistoryList() {
    return Expanded(
      child: _history.isEmpty
          ? const Center(child: Text("Heç bir əməliyyat tapılmadı."))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final historyItem = _history[index];
          return Card(
            margin: const EdgeInsets.symmetric(
                vertical: 4.0, horizontal: 8.0),
            child: ListTile(
              leading: _getHistoryIcon(historyItem.eventType),
              title: Text(historyItem.description),
              subtitle: Text(DateFormat('dd.MM.yyyy, HH:mm')
                  .format(historyItem.eventDate.toLocal())),
            ),
          );
        },
      ),
    );
  }

  Icon _getHistoryIcon(String eventType) {
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
}