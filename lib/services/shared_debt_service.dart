import 'package:flutter/material.dart';
import 'dart:convert';
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
      // Siyahını yükləyə bilmirsə boş qaytarsın, amma istifadəçiyə xəta atmasın (Login ekranına atmamaq üçün)
      return [];
    }
  }

  // --- DÜZƏLDİLMİŞ HİSSƏ: BORC YARATMA ---
  Future<void> createSharedDebtRequest(BuildContext context, SharedDebtRequest request) async {
    // 1. Loga baxaq görək nə göndəririk (Debug üçün)
    print("SENDING JSON: ${jsonEncode(request.toJson())}");

    final response = await ApiService.post(
        context, '$_endpoint/request', body: request.toJson());

    print("SERVER RESPONSE CODE: ${response.statusCode}");
    print("SERVER RESPONSE BODY: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return; // Uğurlu
    } else {
      // Serverdən JSON gəlməyə bilər (HTML gələ bilər), ona görə try-catch edirik
      String errorMessage;
      try {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        errorMessage = errorBody['message'] ?? "Serverdə xəta baş verdi (Kod: ${response.statusCode})";
      } catch (e) {
        // Əgər JSON deyilsə, deməli server başqa xəta qaytarıb (Məs: 502 Bad Gateway)
        errorMessage = "Gözlənilməyən xəta: ${response.statusCode}. \nServer cavabı: ${response.body}";
      }
      throw Exception(errorMessage);
    }
  }

  // Qarşılıqlı borc sorğusuna cavab verir (qəbul/rədd)
  Future<void> respondToSharedDebtRequest(BuildContext context, int debtId, SharedDebtResponseRequest responseData) async {
    final response = await ApiService.post(
        context, '$_endpoint/$debtId/respond', body: responseData.toJson());

    if (response.statusCode != 200) {
      String errorMessage;
      try {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        errorMessage = errorBody['message'] ?? "Xəta";
      } catch(e) {
        errorMessage = "Xəta kodu: ${response.statusCode}";
      }
      throw Exception(errorMessage);
    }
  }

  // Təklif göndərmə
  Future<void> createUpdateProposal(BuildContext context, int debtId, UpdateProposalRequest proposal) async {
    final response = await ApiService.post(
        context, '$_endpoint/$debtId/propose-update', body: proposal.toJson());

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else {
      String errorMessage;
      try {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        errorMessage = errorBody['message'] ?? "Təklif göndərilə bilmədi";
      } catch(e) {
        errorMessage = "Server xətası: ${response.statusCode}";
      }
      throw Exception(errorMessage);
    }
  }

  // Dəyişiklik təklifinə cavab verir
  Future<void> respondToUpdateProposal(BuildContext context, int proposalId, SharedDebtResponseRequest responseData) async {
    final response = await ApiService.post(
        context, '$_endpoint/proposals/$proposalId/respond', body: responseData.toJson());

    if (response.statusCode != 200) {
      String errorMessage;
      try {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        errorMessage = errorBody['message'] ?? "Təklifə cavab verərkən xəta oldu";
      } catch(e) {
        errorMessage = "Xəta kodu: ${response.statusCode}";
      }
      throw Exception(errorMessage);
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