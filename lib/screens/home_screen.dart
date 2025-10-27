import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:borc_defteri/services/debt_service.dart';
import 'package:borc_defteri/models/debt.dart';
import 'package:borc_defteri/screens/debt_details_screen.dart';
import 'package:borc_defteri/screens/add_debt_screen.dart';
import 'package:borc_defteri/screens/login_page.dart';
import 'package:borc_defteri/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.title = 'Borc Dəftəri'});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final String _adUnitId = 'ca-app-pub-1488367137709334/1316894904';
  List<Debt> _allDebts = [];
  bool _isLoading = true;
  final DebtService _debtService = DebtService();
  final AuthService _authService = AuthService();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _activeFilterInfo = 'Bütün Borclar';
  String _currentFilterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _checkSignInStatusAndLoadDebts();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchEmailApp() async {
    const String email = 'ibrahimovbilal9@gmail.com';
    const String subject = 'Borc Dəftəri - Geri Bildiriş';
    const String body = 'Salam,\n\nTətbiqlə bağlı fikirlərim bunlardır:\n\n';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=$subject&body=$body',
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email proqramı tapılmadı!')),
        );
      }
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _checkSignInStatusAndLoadDebts() async {
    bool signedIn = await _authService.isSignedIn();
    if (!signedIn) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } else {
      _loadDebts();
    }
  }

  Future<void> _loadDebts({int? year, int? month}) async {
    if (_isSearching) return;
    setState(() => _isLoading = true);

    try {
      List<Debt> fetchedDebts = [];
      String filterInfo = 'Bütün Borclar';

      switch (_currentFilterType) {
        case 'my_debts':
          fetchedDebts = await _debtService.getMyDebts(context);
          filterInfo = 'Mənim Borclarım';
          break;
        case 'debts_to_me':
          fetchedDebts = await _debtService.getDebtsToMe(context);
          filterInfo = 'Mənə Olan Borclar';
          break;
        case 'flexible':
          fetchedDebts = await _debtService.getFlexibleDebts(context);
          filterInfo = '"Pulum Olanda" Borcları';
          break;
        case 'by_month':
          if (year != null && month != null) {
            fetchedDebts = await _debtService.getDebtsByYearAndMonth(context, year, month);
            filterInfo = '$year / $month-ci Ay Borcları';
          }
          break;
        case 'all':
        default:
          fetchedDebts = await _debtService.getAllDebts(context);
          filterInfo = 'Bütün Borclar';
          break;
      }

      if (mounted) {
        setState(() {
          _allDebts = fetchedDebts;
          _activeFilterInfo = filterInfo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Məlumatları yükləmək alınmadı: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

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
    final List<String> months = [
      'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'İyun',
      'İyul', 'Avqust', 'Sentyabr', 'Oktyabr', 'Noyabr', 'Dekabr'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tarixə Görə Filtr'),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true, value: selectedYear,
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (val) => setDialogState(() => selectedYear = val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true, value: selectedMonth,
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
                      onChanged: (val) => setDialogState(() => selectedMonth = val),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv Et')),
                TextButton(
                  onPressed: () {
                    if (selectedYear != null && selectedMonth != null) {
                      setState(() => _currentFilterType = 'by_month');
                      _loadDebts(year: selectedYear, month: selectedMonth);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Filtrlə'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  AppBar _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _stopSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ad ilə axtar...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (value) async {
            setState(() => _isLoading = true);
            List<Debt> fetchedDebts = await _debtService.searchDebtsByName(context, value);
            if (mounted) {
              setState(() {
                _allDebts = fetchedDebts;
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Yenilə',
            onPressed: () => _loadDebts(),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _startSearch,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              if (value == 'contact_us') {
                _launchEmailApp(); return;
              }
              if (value == 'by_month') {
                _showMonthFilterDialog(); return;
              }
              setState(() {
                _currentFilterType = value;
              });
              _loadDebts();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'all', child: Text('Bütün Borclar')),
              const PopupMenuItem<String>(value: 'my_debts', child: Text('Mənim Borclarım')),
              const PopupMenuItem<String>(value: 'debts_to_me', child: Text('Mənə Olan Borclar')),
              const PopupMenuItem<String>(value: 'flexible', child: Text('"Pulum Olanda"')),
              const PopupMenuItem<String>(value: 'by_month', child: Text('İl/Ay üzrə...')),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'contact_us',
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Bizimlə Əlaqə'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Çıxış',
            onPressed: _showSignOutConfirmationDialog,
          ),
        ],
      );
    }
  }

  void _showSignOutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Təsdiq'),
          content: const Text('Borc dəftərindən çıxmaq istədiyinizdən əminsiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Ləğv Et'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Bəli, Çıxış Et'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _authService.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToAddDebtScreen() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddDebtScreen())
    );
    if (result == true) {
      _loadDebts();
    }
  }

  void _navigateToDetailsScreen(int debtId) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DebtDetailsScreen(debtId: debtId))
    );
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
              child: Text(
                'Göstərilir: $_activeFilterInfo',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF333333)),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
                  : _allDebts.isEmpty
                  ? const Center(child: Text("Heç bir borc tapılmadı.", style: TextStyle(color: Colors.black54, fontSize: 16)))
                  : ListView.builder(
                itemCount: _allDebts.length,
                itemBuilder: (context, index) {
                  final debt = _allDebts[index];

                  // === YENİ və TƏKMİLLƏŞDİRİLMİŞ RƏNG MƏNTİQİ BURADA BAŞLAYIR ===
                  final now = DateTime.now();
                  final int currentYear = now.year;
                  final int currentMonth = now.month;

                  // 1. Borcun vaxtının keçib-keçmədiyini yoxlayırıq
                  bool isOverdue = false;
                  // Yalnız tarixi qeyri-müəyyən olmayanları yoxlayırıq
                  if (!debt.isFlexibleDueDate && debt.dueYear != null && debt.dueMonth != null) {
                    // Əgər borcun ili keçmiş ildirsə, vaxtı keçib
                    if (debt.dueYear! < currentYear) {
                      isOverdue = true;
                    }
                    // Əgər il eyni il, amma ay keçmiş aydırsa, yenə vaxtı keçib
                    else if (debt.dueYear! == currentYear && debt.dueMonth! < currentMonth) {
                      isOverdue = true;
                    }
                  }

                  // 2. Bu ay ödənilməli olub-olmadığını yoxlayırıq
                  // Yalnız vaxtı keçməyibsə və tarixi qeyri-müəyyən deyilsə yoxlayırıq
                  final bool isDueThisMonth = !isOverdue &&
                      !debt.isFlexibleDueDate &&
                      (debt.dueYear == currentYear && debt.dueMonth == currentMonth);

                  // === RƏNG MƏNTİQİ BURADA BİTİR ===

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      // === YENİ RƏNG ATAMASI ===
                      // Prioritet: Qırmızı > Sarı > Ağ
                      color: isOverdue
                          ? Colors.red.shade100   // Vaxtı keçibsə, açıq qırmızı
                          : isDueThisMonth
                          ? Colors.amber.shade100 // Bu aydırsa, sarı
                          : Colors.white,           // Heç biri deyilsə, ağ
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _navigateToDetailsScreen(debt.id),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFAB47BC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${debt.debtAmount.toInt()}₼',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(debt.debtorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF333333))),
                                    const SizedBox(height: 4),
                                    Text(
                                      debt.description != null && debt.description!.isNotEmpty ? debt.description! : 'Növü təyin edilməyib',
                                      style: const TextStyle(color: Colors.black54, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
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
      bottomNavigationBar: _isBannerAdLoaded
          ? SizedBox(
        height: _bannerAd!.size.height.toDouble(),
        width: _bannerAd!.size.width.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      )
          : const SizedBox(),
    );
  }
}