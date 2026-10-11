import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:borc_defteri/models/debt.dart';
import 'package:borc_defteri/models/debt_summary.dart';
import 'package:borc_defteri/models/unified_debt_item.dart';
import 'package:borc_defteri/screens/debt_details_screen.dart';
import 'package:borc_defteri/services/debt_service.dart';

// Yalnız rəqəm qəbul edir, nöqtələri özü qoyur: 11112025 -> 11.11.2025
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');

    // İstifadəçi yalnız nöqtəni silməyə çalışıbsa, ondan əvvəlki rəqəmi silirik
    if (newValue.text.length < oldValue.text.length &&
        digits == oldDigits &&
        digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('.');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class DebtSummaryScreen extends StatefulWidget {
  const DebtSummaryScreen({super.key});

  @override
  State<DebtSummaryScreen> createState() => _DebtSummaryScreenState();
}

class _DebtSummaryScreenState extends State<DebtSummaryScreen> {
  static const Color _purple = Color(0xFF6A1B9A);
  static final DateFormat _fmt = DateFormat('dd.MM.yyyy');

  final DebtService _debtService = DebtService();
  final TextEditingController _startCtrl = TextEditingController();
  final TextEditingController _endCtrl = TextEditingController();

  DebtSummary? _summary;
  DateTime? _from; // hazırda tətbiq olunmuş aralıq
  DateTime? _to;
  bool _showMyDebts = false;
  bool _isLoading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await _debtService.getDebtSummary(
        context,
        startDate: _from,
        endDate: _to,
      );
      if (mounted) setState(() => _summary = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // "11.11.2025" -> DateTime, mövcud olmayan tarix üçün null
  DateTime? _parse(String text) {
    if (text.length != 10) return null;
    final p = text.split('.');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null || y < 2000) return null;
    final dt = DateTime(y, m, d);
    if (dt.day != d || dt.month != m || dt.year != y) return null;
    return dt;
  }

  String? _errorFor(String text) {
    if (text.length == 10 && _parse(text) == null) return 'Belə tarix yoxdur';
    return null;
  }

  void _onFieldChanged() {
    setState(() {}); // səhv mətnini yeniləmək üçün

    final startEmpty = _startCtrl.text.isEmpty;
    final endEmpty = _endCtrl.text.isEmpty;
    final s = _parse(_startCtrl.text);
    final e = _parse(_endCtrl.text);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? from;
    DateTime? to;
    if (startEmpty && endEmpty) {
      from = null;
      to = null;
    } else if (s != null && e != null) {
      from = s;
      to = e;
    } else if (s != null && endEmpty) {
      from = s;
      to = today;
    } else if (e != null && startEmpty) {
      from = DateTime(2000);
      to = e;
    } else {
      return; // hələ yazır, gözləyirik
    }

    // Başlanğıc sondan böyükdürsə, səssizcə yerini dəyişirik
    if (from != null && to != null && from.isAfter(to)) {
      final tmp = from;
      from = to;
      to = tmp;
    }

    if (from == _from && to == _to) return;
    _from = from;
    _to = to;
    _load();
  }

  void _setRange(DateTime from, DateTime to) {
    _startCtrl.text = _fmt.format(from);
    _endCtrl.text = _fmt.format(to);
    setState(() {
      _from = from;
      _to = to;
    });
    _load();
  }

  void _clearRange() {
    _startCtrl.clear();
    _endCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _from = null;
      _to = null;
    });
    _load();
  }

  void _thisMonth() {
    final n = DateTime.now();
    _setRange(DateTime(n.year, n.month, 1), DateTime(n.year, n.month, n.day));
  }

  void _lastMonth() {
    final n = DateTime.now();
    _setRange(DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 0));
  }

  void _last30Days() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    _setRange(today.subtract(const Duration(days: 29)), today);
  }

  void _last6Months() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    // 6 ay əvvəlki eyni gün (ayın sonu uyğun gəlməsə, həmin ayın son günü)
    final lastDayOfTargetMonth = DateTime(n.year, n.month - 6 + 1, 0).day;
    final day = n.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : n.day;
    _setRange(DateTime(n.year, n.month - 6, day), today);
  }

  void _lastYear() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    // 1 il əvvəlki eyni gün (29 fevral kimi hallarda həmin ayın son günü)
    final lastDayOfTargetMonth = DateTime(n.year - 1, n.month + 1, 0).day;
    final day = n.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : n.day;
    _setRange(DateTime(n.year - 1, n.month, day), today);
  }

  // 123.5 -> "123 manat 50 qəpik"
  String _formatAmount(double value) {
    final totalQepik = (value * 100).round();
    final manat = totalQepik ~/ 100;
    final qepik = totalQepik % 100;
    if (qepik == 0) return '$manat manat';
    if (manat == 0) return '$qepik qəpik';
    return '$manat manat $qepik qəpik';
  }

  String get _rangeText => (_from == null || _to == null)
      ? 'Bütün tarixlər'
      : '${_fmt.format(_from!)} - ${_fmt.format(_to!)} arası';

  Color _cardColor(Debt debt) {
    if (debt.isFlexibleDueDate || debt.dueYear == null || debt.dueMonth == null) {
      return Colors.white;
    }
    final now = DateTime.now();
    final overdue = debt.dueYear! < now.year ||
        (debt.dueYear! == now.year && debt.dueMonth! < now.month);
    if (overdue) return Colors.red.shade100;
    if (debt.dueYear! == now.year && debt.dueMonth! == now.month) {
      return Colors.amber.shade100;
    }
    return Colors.white;
  }

  Future<void> _openDetails(Debt debt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DebtDetailsScreen(item: UnifiedDebtItem.fromPersonalDebt(debt)),
      ),
    );
    if (result == true) {
      _changed = true;
      _load();
    }
  }

  Widget _buildDateField(
      String label, TextEditingController controller) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [_DateInputFormatter()],
        onChanged: (_) => _onFieldChanged(),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'gg.aa.iiii',
          errorText: _errorFor(controller.text),
          isDense: true,
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _purple, width: 2)),
        ),
      ),
    );
  }

  Widget _buildDateBar() {
    final hasRange = _startCtrl.text.isNotEmpty || _endCtrl.text.isNotEmpty;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateField('Başlanğıc tarix', _startCtrl),
              const SizedBox(width: 12),
              _buildDateField('Son tarix', _endCtrl),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(label: const Text('Bu ay'), onPressed: _thisMonth),
              ActionChip(label: const Text('Keçən ay'), onPressed: _lastMonth),
              ActionChip(
                  label: const Text('Son 30 gün'), onPressed: _last30Days),
              ActionChip(
                  label: const Text('Son 6 ay'), onPressed: _last6Months),
              ActionChip(
                  label: const Text('Son 1 il'), onPressed: _lastYear),
              if (hasRange)
                TextButton.icon(
                  onPressed: _clearRange,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Təmizlə'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard({
    required String title,
    required double total,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
              Text(_formatAmount(total),
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

  Widget _buildDebtCard(Debt debt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        color: _cardColor(debt),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDetails(debt),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFAB47BC),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${debt.debtAmount.toStringAsFixed(2)}₼',
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
                      Text(debt.description ?? 'Növü təyin edilməyib',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 14)),
                    ],
                  ),
                ),
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
    final summary = _summary;
    if (summary == null) {
      return const Center(child: Text('Məlumat yüklənmədi.'));
    }
    final list = _showMyDebts ? summary.myDebts : summary.debtsToMe;
    if (list.isEmpty) {
      return const Center(
        child: Text('Bu tarix aralığında borc yoxdur',
            style: TextStyle(color: Colors.black54, fontSize: 16)),
      );
    }
    return RefreshIndicator(
      color: _purple,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildDebtCard(list[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tarixə görə xülasə',
              style: TextStyle(color: Colors.white)),
          backgroundColor: _purple,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Container(
          color: const Color(0xFFF0F2F5),
          child: Column(
            children: [
              _buildDateBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _buildTotalCard(
                      title: 'Mənim borclarım',
                      total: summary?.myDebtsTotal ?? 0,
                      selected: _showMyDebts,
                      onTap: () => setState(() => _showMyDebts = true),
                    ),
                    const SizedBox(width: 12),
                    _buildTotalCard(
                      title: 'Mənə olan borclar',
                      total: summary?.debtsToMeTotal ?? 0,
                      selected: !_showMyDebts,
                      onTap: () => setState(() => _showMyDebts = false),
                    ),
                  ],
                ),
              ),
              // Padding(
              //   padding: const EdgeInsets.only(bottom: 4),
              //   child: Text('Yaradılma tarixinə görə: $_rangeText',
              //       style:
              //       const TextStyle(fontSize: 12, color: Colors.black45)),
              // ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Column(
                  children: [
                    Text('Yaradılma tarixinə görə: $_rangeText',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                    const SizedBox(height: 2),
                    const Text(
                        'Qeyd: burada yalnız fərdi borclar göstərilir (qarşılıqlı borclar daxil deyil).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.black54)),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:borc_defteri/models/debt.dart';
// import 'package:borc_defteri/models/debt_summary.dart';
// import 'package:borc_defteri/models/unified_debt_item.dart';
// import 'package:borc_defteri/screens/debt_details_screen.dart';
// import 'package:borc_defteri/services/debt_service.dart';
//
// class DebtSummaryScreen extends StatefulWidget {
//   const DebtSummaryScreen({super.key});
//
//   @override
//   State<DebtSummaryScreen> createState() => _DebtSummaryScreenState();
// }
//
// class _DebtSummaryScreenState extends State<DebtSummaryScreen> {
//   static const Color _purple = Color(0xFF6A1B9A);
//   static const List<String> _months = [
//     'Yan', 'Fev', 'Mar', 'Apr', 'May', 'İyn', 'İyl', 'Avq', 'Sen', 'Okt', 'Noy', 'Dek'
//   ];
//
//   final DebtService _debtService = DebtService();
//   DebtSummary? _summary;
//   DateTimeRange? _range;
//   bool _showMyDebts = true; // ilk açılışda "Mənim borclarım"
//   bool _isLoading = true;
//   bool _changed = false; // home-u yeniləmək üçün
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   Future<void> _load() async {
//     setState(() => _isLoading = true);
//     try {
//       final result = await _debtService.getDebtSummary(
//         context,
//         startDate: _range?.start,
//         endDate: _range?.end,
//       );
//       if (mounted) setState(() => _summary = result);
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text(e.toString())));
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _pickRange() async {
//     final now = DateTime.now();
//     final picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2024),
//       lastDate: DateTime(now.year, now.month, now.day),
//       initialDateRange: _range,
//     );
//     if (picked != null) {
//       setState(() => _range = picked);
//       _load();
//     }
//   }
//
//   void _clearRange() {
//     setState(() => _range = null);
//     _load();
//   }
//
//   // 123.5 -> "123 manat 50 qəpik"
//   String _formatAmount(double value) {
//     final totalQepik = (value * 100).round();
//     final manat = totalQepik ~/ 100;
//     final qepik = totalQepik % 100;
//     if (qepik == 0) return '$manat manat';
//     if (manat == 0) return '$qepik qəpik';
//     return '$manat manat $qepik qəpik';
//   }
//
//   String _formatDate(DateTime d) {
//     final base = '${d.day} ${_months[d.month - 1]}';
//     return d.year == DateTime.now().year ? base : '$base ${d.year}';
//   }
//
//   String get _rangeText => _range == null
//       ? 'Bütün tarixlər'
//       : '${_formatDate(_range!.start)} - ${_formatDate(_range!.end)}';
//
//   Color _cardColor(Debt debt) {
//     if (debt.isFlexibleDueDate || debt.dueYear == null || debt.dueMonth == null) {
//       return Colors.white;
//     }
//     final now = DateTime.now();
//     final overdue = debt.dueYear! < now.year ||
//         (debt.dueYear! == now.year && debt.dueMonth! < now.month);
//     if (overdue) return Colors.red.shade100;
//     if (debt.dueYear! == now.year && debt.dueMonth! == now.month) {
//       return Colors.amber.shade100;
//     }
//     return Colors.white;
//   }
//
//   Future<void> _openDetails(Debt debt) async {
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) =>
//             DebtDetailsScreen(item: UnifiedDebtItem.fromPersonalDebt(debt)),
//       ),
//     );
//     if (result == true) {
//       _changed = true;
//       _load();
//     }
//   }
//
//   Widget _buildDateBar() {
//     return Container(
//       width: double.infinity,
//       color: Colors.white,
//       padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
//       child: Row(
//         children: [
//           Expanded(
//             child: InkWell(
//               onTap: _pickRange,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.calendar_month, color: _purple),
//                     const SizedBox(width: 8),
//                     Flexible(
//                       child: Text(_rangeText,
//                           style: const TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.w600)),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           if (_range != null)
//             TextButton.icon(
//               onPressed: _clearRange,
//               icon: const Icon(Icons.close, size: 18),
//               label: const Text('Təmizlə'),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTotalCard({
//     required String title,
//     required double total,
//     required bool selected,
//     required VoidCallback onTap,
//   }) {
//     return Expanded(
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: selected ? _purple : Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: _purple, width: 1.5),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(title,
//                   style: TextStyle(
//                       fontSize: 13,
//                       color: selected ? Colors.white70 : Colors.black54)),
//               const SizedBox(height: 6),
//               Text(_formatAmount(total),
//                   style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: selected ? Colors.white : _purple)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDebtCard(Debt debt) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
//       child: Card(
//         color: _cardColor(debt),
//         elevation: 4,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           onTap: () => _openDetails(debt),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               children: [
//                 Container(
//                   width: 84,
//                   height: 50,
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   decoration: BoxDecoration(
//                       color: const Color(0xFFAB47BC),
//                       borderRadius: BorderRadius.circular(10)),
//                   child: Center(
//                     child: FittedBox(
//                       fit: BoxFit.scaleDown,
//                       child: Text('${debt.debtAmount.toStringAsFixed(2)}₼',
//                           style: const TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16)),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(debt.debtorName,
//                           style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 18,
//                               color: Color(0xFF333333))),
//                       const SizedBox(height: 4),
//                       Text(debt.description ?? 'Növü təyin edilməyib',
//                           style: const TextStyle(
//                               color: Colors.black54, fontSize: 14)),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBody() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator(color: _purple));
//     }
//     final summary = _summary;
//     if (summary == null) {
//       return const Center(child: Text('Məlumat yüklənmədi.'));
//     }
//     final list = _showMyDebts ? summary.myDebts : summary.debtsToMe;
//     if (list.isEmpty) {
//       return const Center(
//         child: Text('Bu tarix aralığında borc yoxdur',
//             style: TextStyle(color: Colors.black54, fontSize: 16)),
//       );
//     }
//     return RefreshIndicator(
//       color: _purple,
//       onRefresh: _load,
//       child: ListView.builder(
//         physics: const AlwaysScrollableScrollPhysics(),
//         itemCount: list.length,
//         itemBuilder: (context, index) => _buildDebtCard(list[index]),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final summary = _summary;
//     return PopScope(
//       canPop: false,
//       onPopInvoked: (didPop) {
//         if (!didPop) Navigator.pop(context, _changed);
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Tarixə görə xülasə',
//               style: TextStyle(color: Colors.white)),
//           backgroundColor: _purple,
//           iconTheme: const IconThemeData(color: Colors.white),
//         ),
//         body: Container(
//           color: const Color(0xFFF0F2F5),
//           child: Column(
//             children: [
//               _buildDateBar(),
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
//                 child: Row(
//                   children: [
//                     _buildTotalCard(
//                       title: 'Mənim borclarım',
//                       total: summary?.myDebtsTotal ?? 0,
//                       selected: _showMyDebts,
//                       onTap: () => setState(() => _showMyDebts = true),
//                     ),
//                     const SizedBox(width: 12),
//                     _buildTotalCard(
//                       title: 'Mənə olan borclar',
//                       total: summary?.debtsToMeTotal ?? 0,
//                       selected: !_showMyDebts,
//                       onTap: () => setState(() => _showMyDebts = false),
//                     ),
//                   ],
//                 ),
//               ),
//               const Padding(
//                 padding: EdgeInsets.only(bottom: 4),
//                 child: Text('Yaradılma tarixinə görə',
//                     style: TextStyle(fontSize: 12, color: Colors.black45)),
//               ),
//               Expanded(child: _buildBody()),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }