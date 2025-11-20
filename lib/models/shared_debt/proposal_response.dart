class ProposalResponse {
  final int id;
  final int debtId;
  final String proposerName;
  final double? originalAmount;
  final double? proposedAmount;
  final String? originalNotes;
  final String? proposedNotes;

  ProposalResponse({
    required this.id,
    required this.debtId,
    required this.proposerName,
    this.originalAmount,
    this.proposedAmount,
    this.originalNotes,
    this.proposedNotes,
  });

  factory ProposalResponse.fromJson(Map<String, dynamic> json) {
    return ProposalResponse(
      id: json['id'],
      debtId: json['debtId'],
      proposerName: json['proposerName'] ?? '',
      originalAmount: json['originalAmount'] != null
          ? (json['originalAmount'] as num).toDouble()
          : null,
      proposedAmount: json['proposedAmount'] != null
          ? (json['proposedAmount'] as num).toDouble()
          : null,
      originalNotes: json['originalNotes'],
      proposedNotes: json['proposedNotes'],
    );
  }
}

// List şəklində gələndə çevirmək üçün köməkçi funksiya
List<ProposalResponse> proposalListFromJson(dynamic json) {
  final List<dynamic> list = json as List<dynamic>;
  return list.map((e) => ProposalResponse.fromJson(e)).toList();
}