// lib/screens/requests_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/shared_debt/shared_debt.dart';
import '../models/shared_debt/shared_debt_response_request.dart'; // BUNU IMPORT EDİRİK
import '../services/shared_debt_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SharedDebtService _sharedDebtService = SharedDebtService();

  List<SharedDebt> _incomingRequests = [];
  List<SharedDebt> _outgoingRequests = [];
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
    if(!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _sharedDebtService.getPendingRequestsForMe(context),
        _sharedDebtService.getPendingRequestsISent(context),
      ]);
      if (mounted) {
        setState(() {
          // ===== DƏYİŞİKLİK 1: "Vaxtı bitmiş" sorğuları filtirləyirik =====
          // Yalnız vaxtı bitməmiş sorğuları siyahıya əlavə edirik
          final now = DateTime.now();
          _incomingRequests = results[0].where((req) => req.requestExpiryTime != null && req.requestExpiryTime!.isAfter(now)).toList();
          _outgoingRequests = results[1].where((req) => req.requestExpiryTime != null && req.requestExpiryTime!.isAfter(now)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sorğuları yükləmək alınmadı: ${e.toString()}")),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gözləyən Sorğular', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: [
            Tab(text: 'GƏLƏNLƏR (${_incomingRequests.length})'),
            Tab(text: 'GÖNDƏRİLƏNLƏR (${_outgoingRequests.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsList(_incomingRequests, isIncoming: true),
          _buildRequestsList(_outgoingRequests, isIncoming: false),
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<SharedDebt> requests, {required bool isIncoming}) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          isIncoming ? 'Sizə göndərilən aktiv sorğu yoxdur.' : 'Göndərdiyiniz aktiv sorğu yoxdur.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return RequestCard(
            key: ValueKey(request.id),
            debtRequest: request,
            isIncoming: isIncoming,
            onAction: _fetchRequests,
          );
        },
      ),
    );
  }
}


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

  // ===== DƏYİŞİKLİK 2: Cavab verildiyini yadda saxlamaq üçün yeni dəyişən =====
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
      // ===== DƏYİŞİKLİK 3: Taymeri yalnız cavab verilməyibsə yeniləyirik =====
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
    if(!mounted) return;
    setState(() {
      _isProcessing = true;
      // ===== DƏYİŞİKLİK 4: Cavab verdiyimizi qeyd edirik və taymeri dayandırırıq =====
      _responded = true;
      _timer?.cancel();
    });

    try {
      // Artıq bu kod düzgün işləməlidir
      final responseRequest = SharedDebtResponseRequest(accepted: accepted);
      await _sharedDebtService.respondToSharedDebtRequest(context, widget.debtRequest.id, responseRequest);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accepted ? 'Sorğu qəbul edildi!' : 'Sorğu rədd edildi!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1), // Mesaj qısa görünsün
        ),
      );

      // 1.5 saniyə sonra siyahını yeniləyirik ki, istifadəçi nə baş verdiyini görsün
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          widget.onAction();
        }
      });

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xəta: ${e.toString()}"), backgroundColor: Colors.red,),
        );
        // Xəta olarsa, taymeri yenidən başladaq ki, istifadəçi yenidən cəhd edə bilsin
        setState(() {
          _responded = false;
          _startTimer();
        });
      }
    } finally {
      // _isProcessing-i burada false etmirik, çünki kart onsuz da yox olacaq
      // Amma xəta halında false etmək lazımdır
      if (mounted && _isProcessing && !_responded) {
        setState(() => _isProcessing = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool isExpired = _timeLeft == Duration.zero;
    final String timerText = _timeLeft != null ? '${_timeLeft!.inMinutes.toString().padLeft(2, '0')}:${(_timeLeft!.inSeconds % 60).toString().padLeft(2, '0')}' : '00:00';

    // ===== DƏYİŞİKLİK 5: Vaxtı bitmiş kartları heç göstərmirik =====
    // Bu yoxlama _fetchRequests-də edildiyi üçün artıq ehtiyac yoxdur, amma hər ehtimala qarşı qala bilər.
    if(isExpired && !_isProcessing) {
      return const SizedBox.shrink(); // Boş widget qaytarır, yəni heç nə göstərmir
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isIncoming
                  ? "${widget.debtRequest.user.name} sizə borc sorğusu göndərib:"
                  : "${widget.debtRequest.counterpartyUser.name} adlı istifadəçiyə sorğu göndərmisiniz:",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${widget.debtRequest.debtAmount.toStringAsFixed(2)} ₼',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.debtRequest.notes != null && widget.debtRequest.notes!.isNotEmpty)
              Text("Qeyd: ${widget.debtRequest.notes}", style: const TextStyle(color: Colors.grey)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status:', style: TextStyle(color: Colors.grey)),
                    Text(
                      _responded ? ( 'Cavablandı' ) : 'Gözləyir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _responded ? Colors.blue : Colors.orange,
                      ),
                    ),
                  ],
                ),
                // ===== DƏYİŞİKLİK 6: Taymeri cavab veriləndə gizlədirik =====
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
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white, backgroundColor: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _respondToRequest(true),
                        icon: const Icon(Icons.check),
                        label: const Text('Qəbul Et'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white, backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
              ),
          ],
        ),
      ),
    );
  }
}