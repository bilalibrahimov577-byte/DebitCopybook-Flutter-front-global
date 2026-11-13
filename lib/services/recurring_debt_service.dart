import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/recurring_debt.dart';
import '../models/recurring_debt_payment.dart';
import 'api_service.dart';

class RecurringDebtService {
  final String _endpoint = '/api/v1/recurring-debts';

  // Xəta olsa exception atır; çağıran yer (home) bunu tutur
  Future<List<RecurringDebt>> getAll(BuildContext context) async {
    final response = await ApiService.get(context, _endpoint);
    if (response.statusCode == 200) {
      return recurringDebtListFromJson(utf8.decode(response.bodyBytes));
    }
    throw Exception('Təkrarlanan borclar yüklənmədi (${response.statusCode}).');
  }

  Future<RecurringDebt> getById(BuildContext context, int id) async {
    final response = await ApiService.get(context, '$_endpoint/$id');
    if (response.statusCode == 200) {
      return RecurringDebt.fromJson(
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    }
    throw Exception(_extractError(response));
  }

  Future<List<RecurringDebtPayment>> getPayments(
      BuildContext context, int id) async {
    final response = await ApiService.get(context, '$_endpoint/$id/payments');
    if (response.statusCode == 200) {
      return recurringPaymentListFromJson(utf8.decode(response.bodyBytes));
    }
    throw Exception(_extractError(response));
  }

  Future<Map<String, dynamic>> create(
      BuildContext context, {
        required String debtorName,
        required String direction,
        required double totalAmount,
        required double installmentAmount,
        required int dueDay,
        String? notes,
      }) async {
    try {
      final response = await ApiService.post(context, _endpoint, body: {
        'debtorName': debtorName,
        'direction': direction,
        'totalAmount': totalAmount,
        'installmentAmount': installmentAmount,
        'dueDay': dueDay,
        'notes': notes,
      });
      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Təkrarlanan borc yaradıldı!'};
      }
      return {'success': false, 'message': _extractError(response)};
    } catch (e) {
      debugPrint('RecurringDebt create xətası: $e');
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  Future<Map<String, dynamic>> pay(
      BuildContext context, int id, double amount) async {
    try {
      final response = await ApiService.post(
          context, '$_endpoint/$id/payments',
          body: {'amount': amount});
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Ödəniş uğurla qəbul edildi!'};
      }
      return {'success': false, 'message': _extractError(response)};
    } catch (e) {
      debugPrint('RecurringDebt pay xətası: $e');
      return {'success': false, 'message': 'Sistem xətası baş verdi.'};
    }
  }

  Future<bool> delete(BuildContext context, int id) async {
    try {
      final response = await ApiService.delete(context, '$_endpoint/$id');
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('RecurringDebt delete xətası: $e');
      return false;
    }
  }

  // Backend iki formatda xəta qaytarır: "message" (mətn) və "messages" (validasiya map-i)
  String _extractError(http.Response response) {
    try {
      final body = json.decode(utf8.decode(response.bodyBytes));
      if (body is Map) {
        if (body['message'] != null) return body['message'].toString();
        final m = body['messages'];
        if (m is Map && m.isNotEmpty) return m.values.join('\n');
      }
    } catch (_) {}
    return 'Bilinməyən xəta baş verdi.';
  }
}