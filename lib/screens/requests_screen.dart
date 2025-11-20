// lib/screens/requests_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/shared_debt/shared_debt.dart';
import '../models/shared_debt/shared_debt_response_request.dart';
import '../models/shared_debt/proposal_response.dart';
import '../services/shared_debt_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SharedDebtService _sharedDebtService = SharedDebtService();

  // Listlər
  List<SharedDebt> _incomingRequests = [];
  List<SharedDebt> _outgoingRequests = [];
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

  // Serverdən məlumatları çəkir
  Future<void> _fetchRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _sharedDebtService.getPendingRequestsForMe(context),
        _sharedDebtService.getPendingRequestsISent(context),
        _sharedDebtService.getIncomingProposals(context),
        _sharedDebtService.getOutgoingProposals(context),
      ]);

      if (mounted) {
        setState(() {
          final now = DateTime.now();

          // 1. Yeni Borc Sorğularını filtirləyirik (Vaxtı bitməyənlər)
          _incomingRequests = (results[0] as List<SharedDebt>)
              .where((req) => req.requestExpiryTime != null && req.requestExpiryTime!.isAfter(now)).toList();

          _outgoingRequests = (results[1] as List<SharedDebt>)
              .where((req) => req.requestExpiryTime != null && req.requestExpiryTime!.isAfter(now)).toList();

          // 2. Dəyişiklik Təkliflərini alırıq
          _incomingProposals = results[2] as List<ProposalResponse>;
          _outgoingProposals = results[3] as List<ProposalResponse>;
        });
      }
    } catch (e) {
      debugPrint("Error fetching requests: $e");
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
          // --- DƏYİŞİKLİK TƏKLİFLƏRİ (ÖDƏNİŞLƏR VƏ S.) ---
          if (proposals.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Təkliflər (${proposals.length})",
                style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
              ),
            ),
            ...proposals.map((prop) => ProposalCard(
              key: ValueKey("prop_${prop.id}"),
              proposal: prop,
              isIncoming: isIncoming,
              onAction: _fetchRequests, // <--- Bu funksiya siyahını yeniləyir
            )),
          ],

          // --- YENİ BORC SORĞULARI ---
          if (debtRequests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Yeni Borc Sorğuları (${debtRequests.length})",
                style: TextStyle(color: Colors.purple[800], fontWeight: FontWeight.bold),
              ),
            ),
            ...debtRequests.map((req) => RequestCard(
              key: ValueKey("req_${req.id}"),
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
// 1. KART: YENİ BORC SORĞUSU (RequestCard)
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
  bool _responded = false;
  final SharedDebtService _sharedDebtService = SharedDebtService();

  @override
  void initState() {
    super.initState();
    if (widget.debtRequest.requestExpiryTime != null) {
      _timeLeft = widget.debtRequest.requestExpiryTime!.difference(DateTime.now());
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
      final diff = widget.debtRequest.requestExpiryTime!.difference(now);

      if (diff.isNegative) {
        _timer?.cancel();
        widget.onAction(); // Vaxt bitdi, siyahını yenilə (Kart silinsin)
      } else {
        setState(() => _timeLeft = diff);
      }
    });
  }

  Future<void> _respond(bool accepted) async {
    setState(() { _isProcessing = true; _responded = true; });
    _timer?.cancel();

    try {
      await _sharedDebtService.respondToSharedDebtRequest(
          context, widget.debtRequest.id, SharedDebtResponseRequest(accepted: accepted)
      );
      // Uğurlu olanda siyahını yenilə
      widget.onAction();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xəta: $e")));
        setState(() { _responded = false; _isProcessing = false; });
        _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft != null && _timeLeft!.isNegative && !_isProcessing) return const SizedBox.shrink();

    final timerText = _timeLeft != null
        ? '${_timeLeft!.inMinutes}:${(_timeLeft!.inSeconds % 60).toString().padLeft(2, '0')}'
        : '...';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isIncoming
                ? "${widget.debtRequest.user.name} sizə borc sorğusu göndərib:"
                : "${widget.debtRequest.counterpartyUser.name} adlı şəxsə sorğu göndərmisiniz:",
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Center(child: Text('${widget.debtRequest.debtAmount.toStringAsFixed(2)} ₼',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)))),

            if (widget.debtRequest.notes != null)
              Padding(padding: const EdgeInsets.only(top:8), child: Text("Qeyd: ${widget.debtRequest.notes}")),

            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_responded ? (widget.isIncoming ? "Cavablandı..." : "Gözlənilir") : "Gözlənilir",
                    style: TextStyle(color: _responded ? Colors.blue : Colors.orange, fontWeight: FontWeight.bold)),
                if (!_responded) Chip(label: Text(timerText), backgroundColor: Colors.grey[200]),
              ],
            ),
            if (widget.isIncoming && !_isProcessing && !_responded)
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () => _respond(false), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Rədd Et", style: TextStyle(color: Colors.white)))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(onPressed: () => _respond(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Qəbul Et", style: TextStyle(color: Colors.white)))),
                ],
              )
          ],
        ),
      ),
    );
  }
}

// =========================================================
// 2. KART: DƏYİŞİKLİK TƏKLİFİ (ProposalCard)
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
  Timer? _timer;
  Duration? _timeLeft;
  bool _isProcessing = false;
  bool _responded = false;
  final SharedDebtService _sharedDebtService = SharedDebtService();

  @override
  void initState() {
    super.initState();
    // 120 saniyə (2 dəqiqə) taymer başlayır
    _timeLeft = const Duration(minutes: 2);
    _startTimer();
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

      setState(() {
        final seconds = _timeLeft!.inSeconds - 1;
        if (seconds <= 0) {
          _timer?.cancel();
          _timeLeft = Duration.zero;
          widget.onAction();
        } else {
          _timeLeft = Duration(seconds: seconds);
        }
      });
    });
  }

  Future<void> _respond(bool accepted) async {
    setState(() { _isProcessing = true; _responded = true; });
    _timer?.cancel();

    try {
      await _sharedDebtService.respondToUpdateProposal(
          context, widget.proposal.id, SharedDebtResponseRequest(accepted: accepted)
      );
      widget.onAction();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xəta: $e")));
        setState(() { _isProcessing = false; _responded = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == Duration.zero) return const SizedBox.shrink();

    final oldAmount = widget.proposal.originalAmount ?? 0;
    final newAmount = widget.proposal.proposedAmount ?? 0;

    final diff = (oldAmount - newAmount).abs();
    final bool isPayment = newAmount < oldAmount;

    // --- YENİ MƏNTİQ BURADADIR ---
    final bool isFullPayment = newAmount == 0; // Əgər yeni məbləğ 0-dırsa

    String titleText = "";

    if (widget.isIncoming) {
      if (widget.proposal.proposedAmount != null) {
        if (isFullPayment) {
          // 1. TAM ÖDƏNİŞ (SİLİNMƏ) MESAJI
          titleText = "${widget.proposal.proposerName} borcu TAM ödədiyini bildirir. Təsdiqləsəniz borc silinəcək.";
        } else if (isPayment) {
          // 2. QİSMƏN ÖDƏNİŞ MESAJI
          titleText = "${widget.proposal.proposerName} sizə olan ${oldAmount.toStringAsFixed(0)} ₼ borcundan ${diff.toStringAsFixed(0)} ₼ ödədiyini bildirir.";
        } else {
          // 3. BORC ARTIRMA MESAJI
          titleText = "${widget.proposal.proposerName} borcu ${diff.toStringAsFixed(0)} ₼ artırmaq istəyir.";
        }
      } else {
        titleText = "${widget.proposal.proposerName} borcun qeydlərini dəyişmək istəyir.";
      }
    } else {
      // Göndərən tərəf üçün mesaj
      if (isFullPayment) {
        titleText = "Borcun tam silinməsi üçün təklif göndərmisiniz:";
      } else {
        titleText = "Göndərdiyiniz təklif (Cavab gözlənilir):";
      }
    }
    // -------------------------------------------------

    final timerText = '${_timeLeft!.inMinutes}:${(_timeLeft!.inSeconds % 60).toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Silinmə təklifidirsə qırmızıya çalan rəng, ödənişdirsə yaşıl, artımdırsa mavi
      color: isFullPayment ? Colors.orange.shade50 : (isPayment ? Colors.green.shade50 : Colors.blue.shade50),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. MƏTN HİSSƏSİ
            Text(titleText,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),

            const SizedBox(height: 12),

            // 2. RƏQƏMLƏR
            if (widget.proposal.proposedAmount != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("${oldAmount.toStringAsFixed(2)} ₼", style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 16)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward, size: 20, color: Colors.black54)),
                    Text("${newAmount.toStringAsFixed(2)} ₼",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: isFullPayment ? Colors.red : (isPayment ? Colors.green : Colors.blue)
                        )
                    ),
                  ],
                ),
              ),

            // 3. YENİ QEYD VARSA
            if (widget.proposal.proposedNotes != null)
              Container(
                margin: const EdgeInsets.only(top:10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text("Yeni Qeyd: ${widget.proposal.proposedNotes}"),
              ),

            const Divider(),

            // 4. TAYMER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Vaxt bitir:", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                Chip(avatar: const Icon(Icons.timer, size:16), label: Text(timerText), backgroundColor: Colors.white),
              ],
            ),

            // 5. DÜYMƏLƏR (Yalnız Gələnlər üçün)
            if (widget.isIncoming && !_isProcessing && !_responded)
              Row(
                children: [
                  Expanded(child: ElevatedButton(
                      onPressed: () => _respond(false),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: const Text("Yalandır (Rədd et)", style: TextStyle(color: Colors.white, fontSize: 12))
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton(
                      onPressed: () => _respond(true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text(isFullPayment ? "Silinsin" : "Təsdiqlə", style: const TextStyle(color: Colors.white))
                  )),
                ],
              )
          ],
        ),
      ),
    );
  }
}
