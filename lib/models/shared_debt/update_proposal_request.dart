// lib/models/shared_debt/update_proposal_request.dart

class UpdateProposalRequest {
  final double? proposedAmount;
  final String? proposedNotes;

  UpdateProposalRequest({this.proposedAmount, this.proposedNotes});

  Map<String, dynamic> toJson() {
    // Yalnız null olmayan dəyərləri JSON-a əlavə edirik
    final map = <String, dynamic>{};
    if (proposedAmount != null) map['proposedAmount'] = proposedAmount;
    if (proposedNotes != null) map['proposedNotes'] = proposedNotes;
    return map;
  }
}