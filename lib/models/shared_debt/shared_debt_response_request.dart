// lib/models/shared_debt/shared_debt_response_request.dart

class SharedDebtResponseRequest {
  final bool accepted;

  SharedDebtResponseRequest({required this.accepted});

  Map<String, dynamic> toJson() {
    return {
      'accepted': accepted,
    };
  }
}