// lib/screens/requests_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/shared_debt/shared_debt.dart';
import '../models/shared_debt/shared_debt_response_request.dart';
import '../models/shared_debt/proposal_response.dart'; // <-- YENİ MODEL
import '../services/shared_debt_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SharedDebtService _sharedDebtService = SharedDebtService();

  // Yeni Borc Sorğuları
  List<SharedDebt> _incomingRequests = [];
  List<SharedDebt> _outgoingRequests = [];

  // Dəyişiklik Təklifləri (Update Proposals)
  List<ProposalResponse> _incomingProposals = [];
  List<ProposalResponse> _outgoingProposals = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 4 fərqli sorğunu paralel göndəririk
      final results = await Future.wait([
        _sharedDebtService.getPendingRequestsForMe(context),    // 0: Gələn Borc Sorğusu
        _sharedDebtService.getPendingRequestsISent(context),    // 1: Gedən Borc Sorğusu
        _sharedDebtService.getIncomingProposals(context),       // 2: Gələn Dəyişiklik Təklifi
        _sharedDebtService.getOutgoingProposals(context),       // 3: Gedən Dəyişiklik Təklifi
      ]);

      if (mounted) {
        setState(() {
          final now = DateTime.now();

          // Yeni Borc Sorğularını filtirləyirik (Vaxtı keçməyənlər)
          _incomingRequests = (results[0] as List<SharedDebt>)
              .where((req) => req.requestExpiryTime != null && req.requestExpiryTime!.isAfter(now)).toList();

          _outgoingRequests = (results[1] as List<SharedDebt>)
              .where((req) => req.requestExpiryTime != null && req.requestExpiryTime!.isAfter(now)).toList();

          // Dəyişiklik Təkliflərini götürürük
          _incomingProposals = results[2] as List<ProposalResponse>;
          _outgoingProposals = results[3] as List<ProposalResponse>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Məlumatları yükləmək alınmadı: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int incomingCount = _incomingRequests.length + _incomingProposals.length;
    int outgoingCount = _outgoingRequests.length + _outgoingProposals.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildiriş Mərkəzi', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: [
            Tab(text: 'GƏLƏNLƏR ($incomingCount)'),
            Tab(text: 'GÖNDƏRİLƏNLƏR ($outgoingCount)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildCombinedList(isIncoming: true),
          _buildCombinedList(isIncoming: false),
        ],
      ),
    );
  }

  Widget _buildCombinedList({required bool isIncoming}) {
    final debtRequests = isIncoming ? _incomingRequests : _outgoingRequests;
    final proposals = isIncoming ? _incomingProposals : _outgoingProposals;

    if (debtRequests.isEmpty && proposals.isEmpty) {
      return Center(
        child: Text(
          isIncoming ? 'Sizə göndərilən heç bir sorğu yoxdur.' : 'Göndərdiyiniz aktiv sorğu yoxdur.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          // 1. Əgər Dəyişiklik Təklifləri varsa, onları göstər
          if (proposals.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Dəyişiklik Təklifləri (${proposals.length})",
                style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
              ),
            ),
            ...proposals.map((prop) => ProposalCard(
              proposal: prop,
              isIncoming: isIncoming,
              onAction: _fetchRequests,
            )),
          ],

          // 2. Əgər Yeni Borc Sorğuları varsa, onları göstər
          if (debtRequests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Yeni Borc Sorğuları (${debtRequests.length})",
                style: TextStyle(color: Colors.purple[800], fontWeight: FontWeight.bold),
              ),
            ),
            ...debtRequests.map((req) => RequestCard(
              key: ValueKey(req.id),
              debtRequest: req,
              isIncoming: isIncoming,
              onAction: _fetchRequests,
            )),
          ],
        ],
      ),
    );
  }
}

// =========================================================
// 1. KART: YENİ BORC SORĞUSU (Sənin köhnə kartın)
// =========================================================
class RequestCard extends StatefulWidget {
  final SharedDebt debtRequest;
  final bool isIncoming;
  final VoidCallback onAction;

  const RequestCard({
    super.key,
    required this.debtRequest,
    required this.isIncoming,
    required this.onAction,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  Timer? _timer;
  Duration? _timeLeft;
  bool _isProcessing = false;
  final SharedDebtService _sharedDebtService = SharedDebtService();
  bool _responded = false;

  @override
  void initState() {
    super.initState();
    if (widget.debtRequest.requestExpiryTime != null) {
      _timeLeft = widget.debtRequest.requestExpiryTime!.difference(DateTime.now());
      if (_timeLeft!.isNegative) {
        _timeLeft = Duration.zero;
      }
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _responded) {
        _timer?.cancel();
        return;
      }
      final now = DateTime.now();
      final expiryTime = widget.debtRequest.requestExpiryTime!;
      if (now.isAfter(expiryTime)) {
        setState(() {
          _timeLeft = Duration.zero;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _timeLeft = expiryTime.difference(now);
        });
      }
    });
  }

  Future<void> _respondToRequest(bool accepted) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _responded = true;
      _timer?.cancel();
    });

    try {
      final responseRequest = SharedDebtResponseRequest(accepted: accepted);
      await _sharedDebtService.respondToSharedDebtRequest(context, widget.debtRequest.id, responseRequest);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accepted ? 'Sorğu qəbul edildi!' : 'Sorğu rədd edildi!'),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) widget.onAction();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xəta: ${e.toString()}"), backgroundColor: Colors.red),
        );
        setState(() {
          _responded = false;
          _startTimer();
        });
      }
    } finally {
      if (mounted && _isProcessing && !_responded) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpired = _timeLeft == Duration.zero;
    final String timerText = _timeLeft != null
        ? '${_timeLeft!.inMinutes.toString().padLeft(2, '0')}:${(_timeLeft!.inSeconds % 60).toString().padLeft(2, '0')}'
        : '00:00';

    if (isExpired && !_isProcessing) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isIncoming
                  ? "${widget.debtRequest.user.name} sizə YENİ borc sorğusu göndərib:"
                  : "${widget.debtRequest.counterpartyUser.name} adlı istifadəçiyə borc sorğusu göndərmisiniz:",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${widget.debtRequest.debtAmount.toStringAsFixed(2)} ₼',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
              ),
            ),
            if (widget.debtRequest.notes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Qeyd: ${widget.debtRequest.notes}", style: const TextStyle(color: Colors.grey)),
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _responded ? 'Cavablandı' : 'Gözləyir',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _responded ? Colors.blue : Colors.orange),
                ),
                if (!_responded)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text(timerText),
                    backgroundColor: Colors.grey.shade200,
                  ),
              ],
            ),
            if (widget.isIncoming && !_isProcessing && !_responded)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _respondToRequest(false),
                        icon: const Icon(Icons.close),
                        label: const Text('Rədd Et'),
                        style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _respondToRequest(true),
                        icon: const Icon(Icons.check),
                        label: const Text('Qəbul Et'),
                        style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// =========================================================
// 2. YENİ KART: DƏYİŞİKLİK TƏKLİFİ (UPDATE PROPOSAL)
// =========================================================
class ProposalCard extends StatefulWidget {
  final ProposalResponse proposal;
  final bool isIncoming;
  final VoidCallback onAction;

  const ProposalCard({
    super.key,
    required this.proposal,
    required this.isIncoming,
    required this.onAction,
  });

  @override
  State<ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends State<ProposalCard> {
  bool _isProcessing = false;
  final SharedDebtService _sharedDebtService = SharedDebtService();

  Future<void> _respondToProposal(bool accepted) async {
    setState(() => _isProcessing = true);
    try {
      final response = SharedDebtResponseRequest(accepted: accepted);
      await _sharedDebtService.respondToUpdateProposal(context, widget.proposal.id, response);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accepted ? "Dəyişiklik qəbul edildi!" : "Dəyişiklik rədd edildi."),
          backgroundColor: accepted ? Colors.green : Colors.red,
        ),
      );

      widget.onAction(); // Siyahını yenilə
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xəta: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      color: Colors.blue.shade50, // Dəyişiklik təklifləri bir az fərqli rəngdə olsun
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isIncoming
                        ? "${widget.proposal.proposerName} borcda DƏYİŞİKLİK istəyir:"
                        : "Dəyişiklik təklifi göndərmisiniz:",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Məbləğ dəyişikliyi varsa göstər
            if (widget.proposal.proposedAmount != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${widget.proposal.originalAmount} ₼",
                    style: const TextStyle(fontSize: 18, color: Colors.grey, decoration: TextDecoration.lineThrough),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward, color: Colors.blue),
                  ),
                  Text(
                    "${widget.proposal.proposedAmount} ₼",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  ),
                ],
              ),

            // Qeyd dəyişikliyi varsa göstər
            if (widget.proposal.proposedNotes != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Yeni Qeyd Təklifi:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(widget.proposal.proposedNotes!, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),

            // Düymələr (Yalnız gələn sorğular üçün)
            if (widget.isIncoming && !_isProcessing)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _respondToProposal(false),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        child: const Text("Rədd et"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _respondToProposal(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: const Text("Təsdiqlə"),
                      ),
                    ),
                  ],
                ),
              ),

            if(_isProcessing)
              const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ))
          ],
        ),
      ),
    );
  }
}