import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/auth_service.dart'; // Sənin servis faylın

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Google Play Console-da yaratdığın Product ID-ni bura yaz
  final String _premiumProductId = 'monthly_limit_100';

  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();

    // Ödəniş dinləyicisini başladırıq
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Xəta baş verərsə bura düşür
    });

    _initStoreInfo();
  }

  // Mağaza məlumatlarını (qiymət və s.) çəkirik
  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isAvailable = false;
        _isLoading = false;
      });
      return;
    }

    const Set<String> _kIds = <String>{'monthly_limit_100'};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);

    if (response.error != null || response.productDetails.isEmpty) {
      setState(() {
        _isAvailable = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _products = response.productDetails;
      _isAvailable = true;
      _isLoading = false;
    });
  }

  // Ödəniş statusunu dinləyən metod
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Gözləmədədir...
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _showSnackBar("Ödəniş zamanı xəta baş verdi", Colors.red);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {

        // ÖDƏNİŞ UĞURLUDUR! İndi backend-ə xəbər verməliyik
        bool deliver = await _verifyPurchase(purchaseDetails);
        if (deliver) {
          await _inAppPurchase.completePurchase(purchaseDetails);
          _showSuccessDialog();
        }
      }
    }
  }

  // Backend-ə doğrulama sorğusu göndərən hissə
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    final authService = AuthService();
    // Backend-də yaratmalı olduğun endpoint: /api/v1/payments/verify
    // Purchase token və s. göndərirsən
    return await authService.sendPurchaseToBackend(purchase.verificationData.serverVerificationData);
  }

  void _buyProduct(ProductDetails product) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Premium-a Keç', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
          : _buildBody(),
    );
  }


  Widget _buildBody() {
    if (!_isAvailable) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Mağaza ilə əlaqə qurulmadı. İnternet bağlantınızı və Google Play hesabınızı yoxlayın.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final product = _products.first;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 30),
          _buildFeatureRow(Icons.all_inclusive, "Limitsiz Borc", "100-ə qədər borc yaratma imkanı"),
          _buildFeatureRow(Icons.sync, "Avtomatik Yedəkləmə", "Məlumatlarınız buludda təhlükəsiz qalır"),
          _buildFeatureRow(Icons.star, "VİP Dəstək", "Yaranan suallara öncəlikli cavab"),
          const SizedBox(height: 40),

          _buildPriceCard(product),

          // --- YENİ ƏLAVƏ: ABUNƏLİYİ BƏRPA ETMƏ DÜYMƏSİ ---
          const SizedBox(height: 10),
          TextButton(
            onPressed: _restorePurchases, // Sənin yazdığın metodu çağırır
            child: const Text(
              "Artıq abunəmisiniz? Abunəliyi bərpa edin",
              style: TextStyle(
                color: Color(0xFF6A1B9A),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          // ------------------------------------------------

          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "İstənilən vaxt abunəliyi dayandıra bilərsiniz.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }



  // Widget _buildBody() {
  //   if (!_isAvailable) {
  //     return const Center(child: Text("Mağaza ilə əlaqə qurulmadı. Yenidən yoxlayın."));
  //   }
  //
  //   final product = _products.first;
  //
  //   return SingleChildScrollView(
  //     child: Column(
  //       children: [
  //         _buildHeader(),
  //         const SizedBox(height: 30),
  //         _buildFeatureRow(Icons.all_inclusive, "Limitsiz Borc", "100-ə qədər borc yaratma imkanı"),
  //         _buildFeatureRow(Icons.sync, "Avtomatik Yedəkləmə", "Məlumatlarınız buludda təhlükəsiz qalır"),
  //         _buildFeatureRow(Icons.star, "VİP Dəstək", "Yaranan suallara öncəlikli cavab"),
  //         const SizedBox(height: 40),
  //         _buildPriceCard(product),
  //         const SizedBox(height: 20),
  //         const Text("İstənilən vaxt abunəliyi dayandıra bilərsiniz.", style: TextStyle(color: Colors.grey, fontSize: 12)),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: const BoxDecoration(
        color: Color(0xFF6A1B9A),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50)),
      ),
      child: const Column(
        children: [
          Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
          SizedBox(height: 10),
          Text("Borc Dəftəri Premium", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String sub) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6A1B9A), size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(sub),
    );
  }

  Widget _buildPriceCard(ProductDetails product) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 15, spreadRadius: 5)],
        border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text("Aylıq Abunəlik", style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 10),
          Text(product.price, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => _buyProduct(product),
              child: const Text('İNDİ AKTİVLƏŞDİR', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Təbriklər!"),
        content: const Text("Artıq Premium üzvsünüz. Limitsiz imkanlardan yararlana bilərsiniz."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialogu bağla
              Navigator.pop(context); // AddDebtScreen-ə qayıt
            },
            child: const Text("Əla"),
          ),
        ],
      ),
    );
  }

  // PremiumScreen daxilində
  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      // Google-dan köhnə (bitməmiş) satınalmaları tələb edirik
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      _showSnackBar("Bərpa zamanı xəta: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }


}