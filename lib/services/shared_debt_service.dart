// lib/services/shared_debt_service.dart

import 'package:flutter/material.dart';
import 'api_service.dart';
import '../models/shared_debt/shared_debt.dart';
import '../models/shared_debt/shared_debt_request.dart';
import '../models/shared_debt/shared_debt_response_request.dart';
import '../models/shared_debt/update_proposal_request.dart';

class SharedDebtService {
  final String _endpoint = "/api/v1/shared-debts";

  // Mənə göndərilən və təsdiq gözləyən sorğuları gətirir
  Future<List<SharedDebt>> getPendingRequestsForMe(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/requests/incoming');
      if (response.statusCode == 200) {
        return sharedDebtListFromJson(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("getPendingRequestsForMe xətası: $e");
      throw Exception('Gələn sorğuları yükləmək alınmadı.');
    }
  }

  // Mənim göndərdiyim və cavab gözləyən sorğuları gətirir
  Future<List<SharedDebt>> getPendingRequestsISent(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/requests/outgoing');
      if (response.statusCode == 200) {
        return sharedDebtListFromJson(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("getPendingRequestsISent xətası: $e");
      throw Exception('Göndərilən sorğuları yükləmək alınmadı.');
    }
  }

  // Bütün təsdiqlənmiş qarşılıqlı borcları gətirir
  Future<List<SharedDebt>> getConfirmedSharedDebts(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/confirmed');
      if (response.statusCode == 200) {
        return sharedDebtListFromJson(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("getConfirmedSharedDebts xətası: $e");
      throw Exception('Təsdiqlənmiş borcları yükləmək alınmadı.');
    }
  }

  // Yeni qarşılıqlı borc sorğusu yaradır
  Future<void> createSharedDebtRequest(BuildContext context, SharedDebtRequest request) async {
    // Bu metod sadəcə sorğunu göndərir, uğurlu olub-olmadığını status kodu ilə biləcəyik.
    // Xəta olarsa, ApiService onu idarə edəcək və ya burada catch bloku işləyəcək.
    await ApiService.post(
        context, '$_endpoint/request', body: request.toJson());
  }

  // Qarşılıqlı borc sorğusuna cavab verir (qəbul/rədd)
  Future<void> respondToSharedDebtRequest(BuildContext context, int debtId, SharedDebtResponseRequest response) async {
    await ApiService.post(
        context, '$_endpoint/$debtId/respond', body: response.toJson());
  }

  // Dəyişiklik təklifi yaradır
  Future<void> createUpdateProposal(BuildContext context, int debtId, UpdateProposalRequest proposal) async {
    await ApiService.post(
        context, '$_endpoint/$debtId/propose-update', body: proposal.toJson());
  }

  // Dəyişiklik təklifinə cavab verir
  Future<void> respondToUpdateProposal(BuildContext context, int proposalId, SharedDebtResponseRequest response) async {
    await ApiService.post(
        context, '$_endpoint/proposals/$proposalId/respond', body: response.toJson());
  }
}