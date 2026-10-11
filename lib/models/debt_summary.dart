import 'debt.dart';

class DebtSummary {
  final List<Debt> myDebts;
  final double myDebtsTotal;
  final List<Debt> debtsToMe;
  final double debtsToMeTotal;

  DebtSummary({
    required this.myDebts,
    required this.myDebtsTotal,
    required this.debtsToMe,
    required this.debtsToMeTotal,
  });

  factory DebtSummary.fromJson(Map<String, dynamic> json) {
    List<Debt> parse(dynamic list) =>
        (list as List? ?? []).map((e) => Debt.fromJson(e)).toList();

    return DebtSummary(
      myDebts: parse(json['myDebts']),
      myDebtsTotal: (json['myDebtsTotal'] as num? ?? 0).toDouble(),
      debtsToMe: parse(json['debtsToMe']),
      debtsToMeTotal: (json['debtsToMeTotal'] as num? ?? 0).toDouble(),
    );
  }
}