// lib/screens/home_screen.dart

import 'dart:async';
import 'package:borc_defteri/models/shared_debt/shared_debt.dart';
import 'package:borc_defteri/screens/requests_screen.dart';
import 'package:borc_defteri/services/shared_debt_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:borc_defteri/services/debt_service.dart';
import 'package:borc_defteri/models/debt.dart';
import 'package:borc_defteri/screens/debt_details_screen.dart';
import 'package:borc_defteri/screens/add_debt_screen.dart';
import 'package:borc_defteri/screens/login_page.dart';
import 'package:borc_defteri/services/auth_service.dart';

// --- YENİ IMPORTLAR ---
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart'; // HapticFeedback (Vibrasiya) üçün lazımdır
// ---------------------

import '../models/unified_debt_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.title = 'Borc Dəftəri'});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<UnifiedDebtItem> _unifiedDebts = [];
  final SharedDebtService _sharedDebtService = SharedDebtService();
  bool _isLoading = true;
  final DebtService _debtService = DebtService();
  final AuthService _authService = AuthService();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _activeFilterInfo = 'Bütün Borclar';
  String _currentFilterType = 'all';
  int _pendingRequestsCount = 0;
  String? _userUniqueId;
  String? _myDebtId;

  // Bildiriş üçün Timer
  Timer? _notificationTimer;

  // Səs oynadan
  final AudioPlayer _audioPlayer = AudioPlayer();
  // Son bilinən sorğu sayı
  int _lastKnownCount = 0;

  @override
  void initState() {
    super.initState();
    _checkSignInStatusAndLoadDebts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notificationTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !_isSearching) {
        _checkPendingRequestsBackground();
      }
    });
  }

  Future<void> _checkPendingRequestsBackground() async {
    try {
      final incomingRequests = await _sharedDebtService.getPendingRequestsForMe(context);
      final incomingProposals = await _sharedDebtService.getIncomingProposals(context);

      int totalCount = incomingRequests.length + incomingProposals.length;

      // Əgər yeni say köhnədən çoxdursa -> Səs çal və Titrə!
      if (totalCount > _lastKnownCount) {
        _playNotificationSound();
      }

      if (mounted) {
        setState(() {
          _pendingRequestsCount = totalCount;
          _lastKnownCount = totalCount;
        });
      }
    } catch (e) {
      debugPrint("Bildiriş yoxlama xətası: $e");
    }
  }

  // --- YENİLƏNMİŞ SƏS VƏ VİBRASİYA METODU ---
  Future<void> _playNotificationSound() async {
    try {
      // 1. Vibrasiya (Flutter-in öz daxili sistemi ilə - Xətasız)
      await HapticFeedback.heavyImpact();

      // 2. Səs (Assets qovluğunda fayl varsa)
      // Əgər assets/sounds/notification.mp3 faylını qoymusansa işləyəcək
      // Qoymamısansa bu sətri bağla
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));

    } catch (e) {
      debugPrint("Səs/Vibrasiya xətası: $e");
    }
  }
  // ----------------------------------------

  Future<void> _launchEmailApp() async {
    const String email = 'ibrahimovbilal9@gmail.com';
    const String subject = 'Borc Dəftəri - Geri Bildiriş';
    const String body = 'Salam,\n\nTətbiqlə bağlı fikirlərim bunlardır:\n\n';
    final Uri emailLaunchUri = Uri(scheme: 'mailto', path: email, query: 'subject=$subject&body=$body');
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw 'Could not launch $emailLaunchUri';
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email proqramı tapılmadı!')));
      }
    }
  }

  Future<void> _checkSignInStatusAndLoadDebts() async {
    bool signedIn = await _authService.isSignedIn();
    if (!signedIn && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    } else {
      final userDebtId = await _authService.getUserDebtId();
      if (mounted) {
        setState(() {
          _userUniqueId = userDebtId;
          _myDebtId = userDebtId;
        });
      }
      await _loadDebts();

      // İlk yükləmədə sayğacı bərabərləşdiririk ki, ilk açılışda səs çıxmasın
      _lastKnownCount = _pendingRequestsCount;
      _startNotificationTimer();
    }
  }

  Future<void> _loadDebts() async {
    if (_isSearching) return;
    setState(() {
      _isLoading = true;
      _currentFilterType = 'all';
    });
    try {
      final results = await Future.wait([
        _debtService.getAllDebts(context),
        _sharedDebtService.getConfirmedSharedDebts(context),
      ]);
      final personalDebts = results[0] as List<Debt>;
      final sharedDebts = results[1] as List<SharedDebt>;

      final incomingRequests = await _sharedDebtService.getPendingRequestsForMe(context);
      final incomingProposals = await _sharedDebtService.getIncomingProposals(context);

      List<UnifiedDebtItem> combinedList = [];
      combinedList.addAll(personalDebts.map((debt) => UnifiedDebtItem.fromPersonalDebt(debt)));
      combinedList.addAll(sharedDebts.map((debt) => UnifiedDebtItem.fromSharedDebt(debt)));
      combinedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _unifiedDebts = combinedList;
          _pendingRequestsCount = incomingRequests.length + incomingProposals.length;
          _lastKnownCount = _pendingRequestsCount; // Burada da yeniləyirik
          _activeFilterInfo = 'Bütün Borclar';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Məlumatları yükləmək alınmadı: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFilteredDebts({int? year, int? month}) async {
    if (_isSearching) return;
    setState(() => _isLoading = true);

    try {
      List<Debt> personalDebts = [];
      List<SharedDebt> allSharedDebts = [];
      List<SharedDebt> filteredSharedDebts = [];
      String filterInfo = 'Bütün Borclar';

      switch (_currentFilterType) {
        case 'my_debts':
          personalDebts = await _debtService.getMyDebts(context);
          filterInfo = 'Mənim Borclarım';
          break;
        case 'debts_to_me':
          personalDebts = await _debtService.getDebtsToMe(context);
          filterInfo = 'Mənə Olan Borclar';
          break;
        case 'flexible':
          personalDebts = await _debtService.getFlexibleDebts(context);
          filterInfo = '"Pulum Olanda" Borcları';
          break;
        case 'by_month':
          if (year != null && month != null) {
            personalDebts = await _debtService.getDebtsByYearAndMonth(context, year, month);
            filterInfo = '$year / $month-ci Ay Borcları';
          }
          break;
        default:
          await _loadDebts();
          return;
      }

      allSharedDebts = await _sharedDebtService.getConfirmedSharedDebts(context);

      switch (_currentFilterType) {
        case 'my_debts':
          filteredSharedDebts = allSharedDebts.where((s) {
            bool iAmOwner = s.user.debtId == _myDebtId;
            if (iAmOwner) {
              return s.description == 'mənim borcum';
            } else {
              return s.description == 'mənə olan borclar';
            }
          }).toList();
          break;

        case 'debts_to_me':
          filteredSharedDebts = allSharedDebts.where((s) {
            bool iAmOwner = s.user.debtId == _myDebtId;
            if (iAmOwner) {
              return s.description == 'mənə olan borclar';
            } else {
              return s.description == 'mənim borcum';
            }
          }).toList();
          break;

        case 'flexible':
          filteredSharedDebts = allSharedDebts.where((s) => s.isFlexibleDueDate).toList();
          break;

        case 'by_month':
          if (year != null && month != null) {
            filteredSharedDebts = allSharedDebts.where((s) => s.dueYear == year && s.dueMonth == month).toList();
          }
          break;
      }

      List<UnifiedDebtItem> combinedList = [];
      combinedList.addAll(personalDebts.map((d) => UnifiedDebtItem.fromPersonalDebt(d)));
      combinedList.addAll(filteredSharedDebts.map((d) => UnifiedDebtItem.fromSharedDebt(d)));

      combinedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _unifiedDebts = combinedList;
          _activeFilterInfo = filterInfo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xəta: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    _loadDebts();
  }

  void _showMonthFilterDialog() {
    int? selectedYear = DateTime.now().year;
    int? selectedMonth = DateTime.now().month;
    final List<int> years = List<int>.generate(5, (i) => DateTime.now().year + i);
    final List<String> months = ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'İyun', 'İyul', 'Avqust', 'Sentyabr', 'Oktyabr', 'Noyabr', 'Dekabr'];
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(title: const Text('Tarixə Görə Filtr'), content: Row(children: [
          Expanded(child: DropdownButton<int>(isExpanded: true, value: selectedYear, items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(), onChanged: (val) => setDialogState(() => selectedYear = val))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButton<int>(isExpanded: true, value: selectedMonth, items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))), onChanged: (val) => setDialogState(() => selectedMonth = val))),
        ]), actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv Et')),
          TextButton(onPressed: () {
            if (selectedYear != null && selectedMonth != null) {
              setState(() => _currentFilterType = 'by_month');
              _loadFilteredDebts(year: selectedYear, month: selectedMonth);
              Navigator.pop(context);
            }
          }, child: const Text('Filtrlə'))
        ]);
      });
    });
  }

  AppBar _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _stopSearch),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Ad ilə axtar...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
          onChanged: (value) async {
            if(value.isEmpty) { _loadDebts(); return; }
            setState(() => _isLoading = true);

            List<Debt> personalResults = await _debtService.searchDebtsByName(context, value);
            List<SharedDebt> allShared = await _sharedDebtService.getConfirmedSharedDebts(context);
            List<SharedDebt> sharedResults = allShared.where((s) {
              final name1 = s.counterpartyUser.name.toLowerCase();
              final name2 = s.user.name.toLowerCase();
              final query = value.toLowerCase();
              return name1.contains(query) || name2.contains(query);
            }).toList();

            List<UnifiedDebtItem> combinedList = [];
            combinedList.addAll(personalResults.map((d) => UnifiedDebtItem.fromPersonalDebt(d)));
            combinedList.addAll(sharedResults.map((d) => UnifiedDebtItem.fromSharedDebt(d)));

            if (mounted) {
              setState(() {
                _unifiedDebts = combinedList;
                _isLoading = false;
                _activeFilterInfo = value.isEmpty ? 'Bütün Borclar' : "'$value' üçün nəticələr";
              });
            }
          },
        ),
      );
    } else {
      return AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Badge(
              label: Text(_pendingRequestsCount.toString()),
              isLabelVisible: _pendingRequestsCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Gözləyən Sorğular',
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestsScreen()));
              if(result == true || result == null) {
                _loadDebts();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), tooltip: 'Yenilə', onPressed: _loadDebts),
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: _startSearch),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              if (value == 'contact_us') { _launchEmailApp(); return; }
              if (value == 'by_month') { _showMonthFilterDialog(); return; }
              setState(() => _currentFilterType = value);
              if (value == 'all') { _loadDebts(); } else { _loadFilteredDebts(); }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'all', child: Text('Bütün Borclar')),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'my_debts', child: Text('Mənim Borclarım')),
              const PopupMenuItem<String>(value: 'debts_to_me', child: Text('Mənə Olan Borclar')),
              const PopupMenuItem<String>(value: 'flexible', child: Text('"Pulum Olanda"')),
              const PopupMenuItem<String>(value: 'by_month', child: Text('İl/Ay üzrə...')),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'contact_us', child: Row(children: [Icon(Icons.email_outlined, color: Colors.black54), SizedBox(width: 8), Text('Bizimlə Əlaqə')])),
            ],
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), tooltip: 'Çıxış', onPressed: _showSignOutConfirmationDialog),
        ],
      );
    }
  }

  void _showSignOutConfirmationDialog() {
    showDialog(context: context, builder: (BuildContext context) {
      return AlertDialog(title: const Text('Təsdiq'), content: const Text('Borc dəftərindən çıxmaq istədiyinizdən əminsiniz?'), actions: <Widget>[
        TextButton(child: const Text('Ləğv Et'), onPressed: () => Navigator.of(context).pop()),
        TextButton(child: const Text('Bəli, Çıxış Et'), onPressed: () async {
          Navigator.of(context).pop();
          await _authService.signOut();
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
          }
        }),
      ]);
    });
  }

  void _navigateToAddDebtScreen() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddDebtScreen()));
    if (result == true) {
      _loadDebts();
    }
  }

  void _navigateToDetailsScreen(UnifiedDebtItem item) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => DebtDetailsScreen(item: item)));
    if (result == true) {
      _loadDebts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        color: const Color(0xFFF0F2F5),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              color: const Color(0xFFE0E0E0),
              child: Text('Göstərilir: $_activeFilterInfo', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF333333))),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: const Color(0xFF6A1B9A).withOpacity(0.1),
              child: Center(
                child: SelectableText.rich(
                  TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                    children: <TextSpan>[
                      const TextSpan(text: 'Sizin unikal ID-niz: '),
                      TextSpan(
                        text: _userUniqueId ?? "Yüklənir...",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _userUniqueId != null ? const Color(0xFF6A1B9A) : Colors.grey,
                            fontSize: 16
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
                  : _unifiedDebts.isEmpty
                  ? const Center(child: Text("Heç bir borc tapılmadı.", style: TextStyle(color: Colors.black54, fontSize: 16)))
                  : ListView.builder(
                itemCount: _unifiedDebts.length,
                itemBuilder: (context, index) {
                  final item = _unifiedDebts[index];
                  if (item.type == DebtType.personal) {
                    return _buildPersonalDebtCard(item);
                  } else {
                    return _buildSharedDebtCard(item);
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddDebtScreen,
        backgroundColor: const Color(0xFF6A1B9A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPersonalDebtCard(UnifiedDebtItem item) {
    final debt = item.data as Debt;
    final now = DateTime.now();
    final int currentYear = now.year;
    final int currentMonth = now.month;

    Color getCardColor() {
      if (debt.isFlexibleDueDate || debt.dueYear == null || debt.dueMonth == null) {
        return Colors.white;
      }
      final bool isOverdue = debt.dueYear! < currentYear ||
          (debt.dueYear! == currentYear && debt.dueMonth! < currentMonth);
      if (isOverdue) {
        return Colors.red.shade100;
      }
      final bool isDueThisMonth = debt.dueYear! == currentYear && debt.dueMonth! == currentMonth;
      if (isDueThisMonth) {
        return Colors.amber.shade100;
      }
      return Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: getCardColor(),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToDetailsScreen(item),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      color: const Color(0xFFAB47BC),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text('${debt.debtAmount.toInt()}₼',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debt.debtorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF333333))),
                      const SizedBox(height: 4),
                      Text(debt.description ?? 'Növü təyin edilməyib',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 14)),
                    ],
                  ),
                ),
                const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.person_outline, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedDebtCard(UnifiedDebtItem item) {
    final debt = item.data as SharedDebt;
    final bool iAmTheOwner = debt.user.debtId == _myDebtId;
    final String mainTitle = iAmTheOwner ? debt.counterpartyUser.name : debt.user.name;

    String descriptionText = debt.description ?? 'Növü təyin edilməyib';
    if (!iAmTheOwner) {
      if (debt.description == 'mənim borcum') {
        descriptionText = 'mənə olan borclar';
      } else if (debt.description == 'mənə olan borclar') {
        descriptionText = 'mənim borcum';
      }
    }

    final now = DateTime.now();
    final int currentYear = now.year;
    final int currentMonth = now.month;

    Color getCardColor() {
      if (debt.isFlexibleDueDate || debt.dueYear == null || debt.dueMonth == null) {
        return Colors.white;
      }
      final bool isOverdue = debt.dueYear! < currentYear ||
          (debt.dueYear! == currentYear && debt.dueMonth! < currentMonth);
      if (isOverdue) {
        return Colors.red.shade100;
      }
      final bool isDueThisMonth = debt.dueYear! == currentYear && debt.dueMonth! == currentMonth;
      if (isDueThisMonth) {
        return Colors.amber.shade100;
      }
      return Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: getCardColor(),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToDetailsScreen(item),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: Colors.blue.shade400, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('${debt.debtAmount.toInt()}₼', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mainTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF333333))),
                      const SizedBox(height: 4),
                      Text(descriptionText, style: const TextStyle(color: Colors.black54, fontSize: 14)),
                    ],
                  ),
                ),
                Padding(padding: const EdgeInsets.only(left: 8.0), child: Icon(Icons.people_outline, color: Colors.blue.shade700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}