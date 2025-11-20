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
    final response = await ApiService.post(
        context, '$_endpoint/request', body: request.toJson());

    // Log əlavə etdim
    print("Create Request Status: ${response.statusCode}");
    print("Create Request Body: ${response.body}");
  }

  // Qarşılıqlı borc sorğusuna cavab verir (qəbul/rədd)
  Future<void> respondToSharedDebtRequest(BuildContext context, int debtId, SharedDebtResponseRequest responseData) async {
    await ApiService.post(
        context, '$_endpoint/$debtId/respond', body: responseData.toJson());
  }

  // Dəyişiklik təklifi yaradır
  Future<void> createUpdateProposal(BuildContext context, int debtId, UpdateProposalRequest proposal) async {
    // Cavabı 'response' dəyişəninə götürürük
    final response = await ApiService.post(
        context, '$_endpoint/$debtId/propose-update', body: proposal.toJson());

    // İndi cavabı terminala yazdırırıq ki, xətanı görək
    print("---------------- LOG START ----------------");
    print("URL: $_endpoint/$debtId/propose-update");
    print("STATUS CODE: ${response.statusCode}");
    print("BODY: ${response.body}");
    print("---------------- LOG END ------------------");
  }

  // Dəyişiklik təklifinə cavab verir
  Future<void> respondToUpdateProposal(BuildContext context, int proposalId, SharedDebtResponseRequest response) async {
    await ApiService.post(
        context, '$_endpoint/proposals/$proposalId/respond', body: response.toJson());
  }

  // --- YENİ ƏLAVƏ EDİLƏNLƏR ---

  // Mənə gələn DƏYİŞİKLİK təkliflərini gətir (Məsələn: kimsə borcu artırmaq istəyir)
  Future<List<ProposalResponse>> getIncomingProposals(BuildContext context) async {
    try {
      final response = await ApiService.get(context, '$_endpoint/proposals/incoming');
      if (response.statusCode == 200) {
        // Serverdən gələn JSON-u Dart obyektinə çeviririk
        return proposalListFromJson(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint("getIncomingProposals xətası: $e");
      return [];
    }
  }

  // Mənim göndərdiyim DƏYİŞİKLİK təkliflərini gətir (Statusunu görmək üçün)
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