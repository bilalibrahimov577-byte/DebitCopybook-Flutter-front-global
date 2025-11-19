// lib/models/unified_debt_item.dart

import 'debt.dart';
import 'shared_debt/shared_debt.dart';

// Bu, ListView-da hansı növ elementin göstərildiyini müəyyən edir
enum DebtType { personal, shared }

class UnifiedDebtItem {
  final DebtType type;
  final dynamic data; // Bu, ya Debt, ya da SharedDebt obyekti olacaq
  final DateTime createdAt; // Sıralama üçün ortaq tarix sahəsi

  UnifiedDebtItem({
    required this.type,
    required this.data,
    required this.createdAt,
  });

  // Debt obyektindən UnifiedDebtItem yaratmaq üçün köməkçi "constructor"
  factory UnifiedDebtItem.fromPersonalDebt(Debt debt) {
    return UnifiedDebtItem(
      type: DebtType.personal,
      data: debt,
      createdAt: DateTime.parse(debt.createdAt),
    );
  }

  // SharedDebt obyektindən UnifiedDebtItem yaratmaq üçün köməkçi "constructor"
  factory UnifiedDebtItem.fromSharedDebt(SharedDebt debt) {
    // Qarşılıqlı borcun yaradılma tarixi yoxdur, amma biz ona aid olan
    // istifadəçinin məlumatlarından istifadə edə bilərik.
    // Əslində sıralama üçün daha dəqiq bir sahə lazımdır.
    // Hələlik sadəlik üçün DateTime.now() istifadə edək, sonra bunu dəqiqləşdirərik.
    // YAXŞI HƏLL: Backend-də SharedDebt-ə də `createdAt` sahəsi əlavə etmək olardı.
    // Hələlik sorğunun bitmə vaxtından və ya indiki vaxtdan istifadə edirik.
    return UnifiedDebtItem(
      type: DebtType.shared,
      data: debt,
      createdAt: debt.requestExpiryTime ?? DateTime.now(), // Təxmini sıralama üçün
    );
  }
}