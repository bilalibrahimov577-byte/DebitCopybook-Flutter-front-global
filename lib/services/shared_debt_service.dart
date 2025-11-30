import 'package:flutter/material.dart';
import 'dart:convert'; // JSON çevirmək üçün lazımdır
import 'api_service.dart';
import '../models/shared_debt/shared_debt.dart';
import '../models/shared_debt/shared_debt_request.dart';
import '../models/shared_debt/shared_debt_response_request.dart';
import '../models/shared_debt/update_proposal_request.dart';
import '../models/shared_debt/proposal_response.dart';

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
      // Siyahını yükləyə bilmirsə boş siyahı qaytarsın, proqram çökməsin
      return [];
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
      return [];
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

  // --- DÜZƏLDİLMİŞ HİSSƏ: BORC YARATMA (LİMİT XƏTASI GÖSTƏRMƏK ÜÇÜN) ---
  Future<void> createSharedDebtRequest(BuildContext context, SharedDebtRequest request) async {
    final response = await ApiService.post(
        context, '$_endpoint/request', body: request.toJson());

    // Serverdən cavabı yoxlayırıq
    if (response.statusCode == 200 || response.statusCode == 201) {
      print("Create Request Status: ${response.statusCode}");
    } else {
      // Əgər xəta varsa (Məsələn: 15 borc limiti dolubsa)
      // Serverdən gələn mesajı oxuyuruq
      final Map<String, dynamic> errorBody = jsonDecode(response.body);
      String errorMessage = errorBody['message'] ?? "Naməlum xəta baş verdi";

      // Xətanı atırıq ki, ekranda SnackBar ilə görünsün
      throw Exception(errorMessage);
    }
  }

  // Qarşılıqlı borc sorğusuna cavab verir (qəbul/rədd)
  Future<void> respondToSharedDebtRequest(BuildContext context, int debtId, SharedDebtResponseRequest responseData) async {
    final response = await ApiService.post(
        context, '$_endpoint/$debtId/respond', body: responseData.toJson());

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorBody = jsonDecode(response.body);
      throw Exception(errorBody['message'] ?? "Sorğuya cavab verərkən xəta oldu");
    }
  }

  // --- DÜZƏLDİLMİŞ HİSSƏ: TƏKLİF GÖNDƏRMƏ (3 TƏKLİF LİMİTİ ÜÇÜN) ---
  Future<void> createUpdateProposal(BuildContext context, int debtId, UpdateProposalRequest proposal) async {
    final response = await ApiService.post(
        context, '$_endpoint/$debtId/propose-update', body: proposal.toJson());

    print("---------------- LOG START ----------------");
    print("URL: $_endpoint/$debtId/propose-update");
    print("STATUS CODE: ${response.statusCode}");
    print("BODY: ${response.body}");
    print("---------------- LOG END ------------------");

    // Status kodunu yoxlayırıq
    if (response.statusCode == 200 || response.statusCode == 201) {
      // Uğurludur
    } else {
      // Xəta var (Limit dolub və ya vaxt bitməyib)
      final Map<String, dynamic> errorBody = jsonDecode(response.body);
      String errorMessage = errorBody['message'] ?? "Təklif göndərilə bilmədi";

      // Xətanı atırıq
      throw Exception(errorMessage);
    }
  }

  // Dəyişiklik təklifinə cavab verir
  Future<void> respondToUpdateProposal(BuildContext context, int proposalId, SharedDebtResponseRequest responseData) async {
    final response = await ApiService.post(
        context, '$_endpoint/proposals/$proposalId/respond', body: responseData.toJson());

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorBody = jsonDecode(response.body);
      throw Exception(errorBody['message'] ?? "Təklifə cavab verərkən xəta oldu");
    }
  }

  // Mənə gələn DƏYİŞİKLİK təkliflərini gətir
  Future<List<ProposalResponse>> getIncomingProposals(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/proposals/incoming');
      if (response.statusCode == 200) {
        return proposalListFromJson(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint("getIncomingProposals xətası: $e");
      return [];
    }
  }

  // Mənim göndərdiyim DƏYİŞİKLİK təkliflərini gətir
  Future<List<ProposalResponse>> getOutgoingProposals(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/proposals/outgoing');
      if (response.statusCode == 200) {
        return proposalListFromJson(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint("getOutgoingProposals xətası: $e");
      return [];
    }
  }
}