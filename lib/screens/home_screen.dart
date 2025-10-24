import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
// === ƏLAQƏ: Lazımi kitabxananı import edirik ===
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
  // ... sənin bütün dəyişənlərin olduğu kimi qalır ...
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

  // === ƏLAQƏ: Email proqramını açan funksiya ===
  Future<void> _launchEmailApp() async {
    // DİQQƏT: Buradakı emaili öz email ünvanınla dəyiş!
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
      // Əgər email proqramı tapılmasa, istifadəçiyə bildiriş göstər
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email proqramı tapılmadı!')),
      );
    }
  }
  // ===============================================

  // ... sənin _loadBannerAd, _checkSignInStatusAndLoadDebts, _filterDebts və digər bütün funksiyaların olduğu kimi qalır ...
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
      _filterDebts('all');
    }
  }

  Future<void> _filterDebts(String filter, {int? year, int? month}) async {
    setState(() => _isLoading = true);

    List<Debt> fetchedDebts = [];
    String filterInfo = 'Bütün Borclar';
    String? token = await _authService.getJwtToken();

    if (token == null) {
      _checkSignInStatusAndLoadDebts();
      return;
    }

    if (filter == 'flexible') {
      //fetchedDebts = await _debtService.getFlexibleDebts();
      fetchedDebts = await _debtService.getFlexibleDebts(context);
      filterInfo = '"Pulum Olanda" Borcları';
    } else if (filter == 'by_month' && year != null && month != null) {
      //fetchedDebts = await _debtService.getDebtsByYearAndMonth(year, month);
      fetchedDebts = await _debtService.getDebtsByYearAndMonth(context, year, month);
      filterInfo = '$year / $month-ci Ay Borcları';
    } else {
      //fetchedDebts = await _debtService.getAllDebts();
      fetchedDebts = await _debtService.getAllDebts(context);
    }

    if (mounted) {
      setState(() {
        _allDebts = fetchedDebts;
        _isLoading = false;
        _activeFilterInfo = filterInfo;
      });
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
    _filterDebts('all');
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
                      isExpanded: true,
                      value: selectedYear,
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (val) => setDialogState(() => selectedYear = val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedMonth,
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
                      _filterDebts('by_month', year: selectedYear, month: selectedMonth);
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
      // ... Axtarış üçün olan AppBar olduğu kimi qalır ...
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
            String? token = await _authService.getJwtToken();
            if (token == null) {
              _checkSignInStatusAndLoadDebts();
              return;
            }
           // List<Debt> fetchedDebts = await _debtService.searchDebtsByName(value);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Yenilə',
            onPressed: () => _filterDebts('all'),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _startSearch,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              if (value == 'all') _filterDebts('all');
              if (value == 'flexible') _filterDebts('flexible');
              if (value == 'by_month') _showMonthFilterDialog();
              // === ƏLAQƏ: Menyudan seçim ediləndə funksiyanı çağırırıq ===
              if (value == 'contact_us') _launchEmailApp();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                  value: 'all', child: Text('Bütün Borclar')),
              const PopupMenuItem<String>(
                  value: 'flexible', child: Text('"Pulum Olanda"')),
              const PopupMenuItem<String>(
                  value: 'by_month', child: Text('İl/Ay üzrə...')),
              // === ƏLAQƏ: Menyunu ayıran xətt və yeni bənd ===
              const PopupMenuDivider(), // Ayırıcı xətt
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
              // =============================================
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

  // ... qalan bütün funksiyalar və build metodu olduğu kimi qalır ...
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
              onPressed: () {
                Navigator.of(context).pop();
              },
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
    String? token = await _authService.getJwtToken();
    if (token == null) {
      _checkSignInStatusAndLoadDebts();
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddDebtScreen())).then((result) {
      if (result == true) _filterDebts('all');
    });
  }

  void _navigateToDetailsScreen(int debtId) async {
    String? token = await _authService.getJwtToken();
    if (token == null) {
      _checkSignInStatusAndLoadDebts();
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => DebtDetailsScreen(debtId: debtId))).then((result) {
      if (result == true) _filterDebts('all');
    });
  }

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final int currentMonth = DateTime.now().month;

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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
                  : _allDebts.isEmpty
                  ? const Center(
                child: Text(
                  "Heç bir borc tapılmadı.",
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              )
                  : ListView.builder(
                itemCount: _allDebts.length,
                itemBuilder: (context, index) {
                  final debt = _allDebts[index];
                  final bool isDueThisMonth = (debt.dueYear == currentYear && debt.dueMonth == currentMonth);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      color: isDueThisMonth ? Colors.amber.shade100 : Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _navigateToDetailsScreen(debt.id),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFAB47BC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${debt.debtAmount.toInt()}₼',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      debt.debtorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      debt.description ?? 'Açıqlama yoxdur',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
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