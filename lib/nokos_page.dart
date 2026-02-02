import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// 🛒 SHOP NOKOS PAGE - Complete Implementation
/// Semua REST API endpoint telah diimplementasikan dengan lengkap
/// 
/// API Endpoints yang tersedia:
/// ✅ GET  /shop/config       - Config shop
/// ✅ GET  /shop/profile      - User profile & balance
/// ✅ GET  /shop/services     - Daftar layanan (paginated)
/// ✅ GET  /shop/countries    - Negara untuk service
/// ✅ GET  /shop/prices       - Harga (server 3 only)
/// ✅ POST /shop/order        - Beli nomor OTP
/// ✅ GET  /shop/check-otp    - Cek kode OTP
/// ✅ POST /shop/refund       - Refund nomor
/// ✅ POST /shop/deposit/create - Buat deposit QRIS
/// ✅ POST /shop/deposit/check  - Cek pembayaran deposit
/// ✅ GET  /shop/orders       - Riwayat order
/// ✅ GET  /shop/deposits     - Riwayat deposit

class NokosPage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final String role;
  final String expiredDate;

  const NokosPage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<NokosPage> createState() => _NokosPageState();
}

class _NokosPageState extends State<NokosPage> with SingleTickerProviderStateMixin {
  // ==========================================
  // 🎨 THEME COLORS
  // ==========================================
  final Color primaryDark = const Color(0xFF000000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF0D0D0D);
  final Color accentRed = const Color(0xFFDC143C);
  final Color accentBlue = const Color(0xFF2196F3);
  final Color goldColor = const Color(0xFFFFD700);

  // ==========================================
  // 🌐 API CONFIGURATION
  // ==========================================
  final String baseUrl = 'https://tapops.fanzhosting.my.id';

  // ==========================================
  // 📊 STATE VARIABLES
  // ==========================================
  
  // Navigation
  int _currentTabIndex = 0;
  
  // Profile & Config
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _configData;
  bool _isLoadingProfile = true;

  // Services
  List<Map<String, dynamic>> _services = [];
  bool _isLoadingServices = false;
  int _currentPage = 0;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _hasPrevPage = false;

  // Selection State
  String? _selectedServiceCode;
  String? _selectedServiceName;
  
  List<Map<String, dynamic>> _countries = [];
  bool _isLoadingCountries = false;
  Map<String, dynamic>? _selectedCountry;
  
  List<Map<String, dynamic>> _prices = [];
  bool _isLoadingPrices = false;
  Map<String, dynamic>? _selectedPrice;

  // Orders & Deposits
  List<Map<String, dynamic>> _orders = [];
  bool _isLoadingOrders = false;
  
  List<Map<String, dynamic>> _deposits = [];
  bool _isLoadingDeposits = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    
    // Initial data load
    _loadConfig();
    _loadProfile();
    _loadServices();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🌐 API IMPLEMENTATION
  // ==========================================

  /// ✅ GET /shop/config
  /// Mendapatkan konfigurasi shop (min_deposit, markup, dll)
  Future<void> _loadConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/config'),
      );

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          _configData = data['data'];
        });
        debugPrint('✅ Config loaded: ${data['data']}');
      }
    } catch (e) {
      debugPrint('❌ Error loading config: $e');
    }
  }

  /// ✅ GET /shop/profile
  /// Mendapatkan profil user & saldo
  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/profile?key=${widget.sessionKey}'),
      );

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          _profileData = data['data'];
          _isLoadingProfile = false;
        });
        debugPrint('✅ Profile loaded: ${data['data']}');
      } else {
        setState(() => _isLoadingProfile = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      setState(() => _isLoadingProfile = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ GET /shop/services
  /// Mendapatkan daftar layanan dengan pagination
  Future<void> _loadServices({int page = 0, int limit = 20}) async {
    setState(() => _isLoadingServices = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/services?key=${widget.sessionKey}&page=$page&limit=$limit'),
      );

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(data['data']['services']);
          _currentPage = data['data']['pagination']['page'];
          _totalPages = data['data']['pagination']['totalPages'];
          _hasNextPage = data['data']['pagination']['hasNext'];
          _hasPrevPage = data['data']['pagination']['hasPrev'];
          _isLoadingServices = false;
        });
        debugPrint('✅ Services loaded: ${_services.length} items, page $_currentPage/$_totalPages');
      } else {
        setState(() => _isLoadingServices = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to load services');
      }
    } catch (e) {
      debugPrint('❌ Error loading services: $e');
      setState(() => _isLoadingServices = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ GET /shop/countries
  /// Mendapatkan daftar negara untuk layanan tertentu
  Future<void> _loadCountries(String serviceCode, String serviceName) async {
    setState(() {
      _isLoadingCountries = true;
      _selectedServiceCode = serviceCode;
      _selectedServiceName = serviceName;
      _countries = [];
      _selectedCountry = null;
      _prices = [];
      _selectedPrice = null;
    });
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/countries?key=${widget.sessionKey}&serviceCode=$serviceCode'),
      );

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          _countries = List<Map<String, dynamic>>.from(data['data']['countries']);
          _isLoadingCountries = false;
        });
        debugPrint('✅ Countries loaded: ${_countries.length} items for $serviceCode');
      } else {
        setState(() => _isLoadingCountries = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to load countries');
      }
    } catch (e) {
      debugPrint('❌ Error loading countries: $e');
      setState(() => _isLoadingCountries = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ GET /shop/prices
  /// Mendapatkan daftar harga (FILTER SERVER 3 ONLY)
  Future<void> _loadPrices(String serviceCode, int numberId, String countryName) async {
    setState(() {
      _isLoadingPrices = true;
      _prices = [];
      _selectedPrice = null;
    });
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/prices?key=${widget.sessionKey}&serviceCode=$serviceCode&numberId=$numberId'),
      );

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          _prices = List<Map<String, dynamic>>.from(data['data']['prices']);
          _isLoadingPrices = false;
        });
        debugPrint('✅ Prices loaded: ${_prices.length} items for $countryName');
      } else {
        setState(() => _isLoadingPrices = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to load prices');
      }
    } catch (e) {
      debugPrint('❌ Error loading prices: $e');
      setState(() => _isLoadingPrices = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ POST /shop/order
  /// Membeli nomor OTP
  Future<void> _createOrder() async {
    if (_selectedServiceCode == null || _selectedCountry == null || _selectedPrice == null) {
      _showErrorSnackbar('Please select service, country, and price');
      return;
    }

    _showLoadingDialog();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/order'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'key': widget.sessionKey,
          'serviceCode': _selectedServiceCode,
          'numberId': _selectedCountry!['id'],
          'providerId': _selectedPrice!['providerId'],
        }),
      );

      Navigator.pop(context); // Close loading

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        debugPrint('✅ Order created: ${data['data']}');
        _showOrderSuccessDialog(data['data']);
        await _loadProfile(); // Refresh balance
        await _loadOrders(); // Refresh orders
        _resetSelection();
      } else {
        _showErrorDialog(data['message'] ?? 'Order failed');
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint('❌ Error creating order: $e');
      _showErrorDialog('Network error: $e');
    }
  }

  /// ✅ GET /shop/check-otp
  /// Cek kode OTP dari order
  Future<void> _checkOTP(String orderId) async {
    _showLoadingDialog();
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/check-otp?key=${widget.sessionKey}&orderId=$orderId'),
      );

      Navigator.pop(context); // Close loading

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        if (data['data']['hasOtp'] == true) {
          debugPrint('✅ OTP found: ${data['data']['otpCode']}');
          _showOTPDialog(data['data']);
          await _loadOrders(); // Refresh to update status
        } else {
          _showInfoDialog('OTP Not Ready', 'OTP code has not been received yet. Please wait and try again.');
        }
      } else {
        _showErrorDialog(data['message'] ?? 'Failed to check OTP');
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint('❌ Error checking OTP: $e');
      _showErrorDialog('Network error: $e');
    }
  }

  /// ✅ POST /shop/refund
  /// Refund nomor (setelah delay)
  Future<void> _refundOrder(String orderId) async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmDialog(
        title: 'Confirm Refund',
        message: 'Are you sure you want to refund this order? This action cannot be undone.',
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/refund'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'key': widget.sessionKey,
          'orderId': orderId,
        }),
      );

      Navigator.pop(context); // Close loading

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        debugPrint('✅ Refund successful: ${data['data']}');
        _showSuccessDialog('Refund Successful', 
          'Amount refunded: Rp ${_formatNumber(data['data']['refundedAmount'])}\n'
          'New balance: Rp ${_formatNumber(data['data']['newBalance'])}'
        );
        await _loadProfile(); // Refresh balance
        await _loadOrders(); // Refresh orders
      } else {
        _showErrorDialog(data['message'] ?? 'Refund failed');
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint('❌ Error refunding order: $e');
      _showErrorDialog('Network error: $e');
    }
  }

  /// ✅ POST /shop/deposit/create
  /// Membuat deposit QRIS
  Future<void> _createDeposit(int amount) async {
    if (_configData != null) {
      final minDeposit = _configData!['min_deposit'] ?? 1000;
      if (amount < minDeposit) {
        _showErrorSnackbar('Minimum deposit is Rp ${_formatNumber(minDeposit)}');
        return;
      }
    }

    _showLoadingDialog();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/deposit/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'key': widget.sessionKey,
          'amount': amount,
        }),
      );

      Navigator.pop(context); // Close loading

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        debugPrint('✅ Deposit created: ${data['data']['orderId']}');
        _showQRISDialog(data['data']);
      } else {
        _showErrorDialog(data['message'] ?? 'Failed to create deposit');
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint('❌ Error creating deposit: $e');
      _showErrorDialog('Network error: $e');
    }
  }

  /// ✅ POST /shop/deposit/check
  /// Cek status pembayaran deposit
  Future<void> _checkDepositStatus(String orderId) async {
    _showLoadingDialog();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/deposit/check'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'key': widget.sessionKey,
          'orderId': orderId,
        }),
      );

      Navigator.pop(context); // Close loading

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        debugPrint('✅ Deposit completed: ${data['data']}');
        _showSuccessDialog('Deposit Successful!', 
          'Amount: Rp ${_formatNumber(data['data']['amount'])}\n'
          'Total Paid: Rp ${_formatNumber(data['data']['totalPaid'])}\n'
          'New Balance: Rp ${_formatNumber(data['data']['newBalance'])}\n'
          'Completed at: ${data['data']['completedAt']}'
        );
        await _loadProfile(); // Refresh balance
        await _loadDeposits(); // Refresh deposits
      } else {
        _showInfoDialog('Payment Not Detected', data['message'] ?? 'Payment has not been completed yet.');
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint('❌ Error checking deposit: $e');
      _showErrorDialog('Network error: $e');
    }
  }

  /// ✅ GET /shop/orders
  /// Mendapatkan riwayat order
  Future<void> _loadOrders({int limit = 20}) async {
    setState(() => _isLoadingOrders = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/orders?key=${widget.sessionKey}&limit=$limit'),
      );

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data['data']['orders']);
          _isLoadingOrders = false;
        });
        debugPrint('✅ Orders loaded: ${_orders.length} items');
      } else {
        setState(() => _isLoadingOrders = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to load orders');
      }
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
      setState(() => _isLoadingOrders = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ GET /shop/deposits
  /// Mendapatkan riwayat deposit
  Future<void> _loadDeposits({int limit = 20}) async {
    setState(() => _isLoadingDeposits = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/deposits?key=${widget.sessionKey}&limit=$limit'),
      );

      final data = json.decode(response.body);
      
      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          _deposits = List<Map<String, dynamic>>.from(data['data']['deposits']);
          _isLoadingDeposits = false;
        });
        debugPrint('✅ Deposits loaded: ${_deposits.length} items');
      } else {
        setState(() => _isLoadingDeposits = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to load deposits');
      }
    } catch (e) {
      debugPrint('❌ Error loading deposits: $e');
      setState(() => _isLoadingDeposits = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  // ==========================================
  // 🛠️ HELPER METHODS
  // ==========================================

  void _resetSelection() {
    setState(() {
      _selectedServiceCode = null;
      _selectedServiceName = null;
      _countries = [];
      _selectedCountry = null;
      _prices = [];
      _selectedPrice = null;
    });
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_searchQuery.isEmpty) return _services;
    
    return _services.where((service) {
      final name = service['name']?.toString().toLowerCase() ?? '';
      final code = service['code']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  // ==========================================
  // 🎨 DIALOG BUILDERS
  // ==========================================

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: cardDark,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: accentBlue),
                const SizedBox(height: 16),
                Text(
                  'Please wait...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: accentRed, size: 28),
            SizedBox(width: 12),
            Text('Error', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: accentBlue)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: Colors.white))),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: accentBlue)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: accentBlue, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: Colors.white))),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: accentBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmDialog({required String title, required String message}) {
    return AlertDialog(
      backgroundColor: cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(color: Colors.white))),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Confirm', style: TextStyle(color: accentRed)),
        ),
      ],
    );
  }

  void _showOrderSuccessDialog(Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Order Successful', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Order ID', orderData['orderId'] ?? '-'),
            _buildInfoRow('Phone Number', orderData['phoneNumber'] ?? '-'),
            _buildInfoRow('Price', orderData['displayPrice'] ?? '-'),
            _buildInfoRow('New Balance', 'Rp ${_formatNumber(orderData['balance'])}'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: accentBlue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderData['phoneNumber'] ?? '-',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap to copy',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: accentBlue),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: orderData['phoneNumber']));
                      _showSuccessSnackbar('Phone number copied!');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: accentBlue)),
          ),
        ],
      ),
    );
  }

  void _showOTPDialog(Map<String, dynamic> otpData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.message, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('OTP Code', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'OTP CODE',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    otpData['otpCode'] ?? '-',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Order ID: ${otpData['orderId']}',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: otpData['otpCode']));
              _showSuccessSnackbar('OTP code copied!');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy, size: 16),
                SizedBox(width: 4),
                Text('Copy'),
              ],
            ),
            style: TextButton.styleFrom(foregroundColor: accentBlue),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
            style: TextButton.styleFrom(foregroundColor: Colors.white60),
          ),
        ],
      ),
    );
  }

  void _showQRISDialog(Map<String, dynamic> qrisData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.qr_code_2, color: accentBlue, size: 28),
            SizedBox(width: 12),
            Text('QRIS Payment', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.memory(
                  base64Decode(qrisData['qrCode'].split(',').last),
                  width: 200,
                  height: 200,
                ),
              ),
              SizedBox(height: 16),
              _buildInfoRow('Order ID', qrisData['orderId'] ?? '-'),
              _buildInfoRow('Amount', qrisData['displayAmount'] ?? '-'),
              _buildInfoRow('Total Payment', qrisData['displayTotal'] ?? '-'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: goldColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: goldColor, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Scan QR code or copy the number below',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: qrisData['qrisNumber']));
                        _showSuccessSnackbar('QRIS number copied!');
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardDarker,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                qrisData['qrisNumber'] ?? '-',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Icon(Icons.copy, color: accentBlue, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkDepositStatus(qrisData['orderId']);
            },
            child: Text('Check Payment'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
            style: TextButton.styleFrom(foregroundColor: Colors.white60),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog() {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: goldColor, size: 28),
            SizedBox(width: 12),
            Text('Deposit Balance', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_configData != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: accentBlue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Min: ${_configData!['display_min_deposit'] ?? 'Rp 1.000'}',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(color: Colors.white60),
                prefixText: 'Rp ',
                prefixStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: accentBlue),
                ),
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [5000, 10000, 25000, 50000, 100000].map((amount) {
                return ChoiceChip(
                  label: Text('${_formatNumber(amount)}'),
                  selected: false,
                  onSelected: (selected) {
                    if (selected) {
                      amountController.text = amount.toString();
                    }
                  },
                  backgroundColor: cardDarker,
                  selectedColor: accentBlue,
                  labelStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                _showErrorSnackbar('Please enter a valid amount');
                return;
              }
              Navigator.pop(context);
              _createDeposit(amount);
            },
            child: Text('Continue', style: TextStyle(color: accentBlue)),
          ),
        ],
      ),
    );
  }

  void _showCountriesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.public, color: accentBlue, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Country',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  if (_selectedServiceName != null)
                    Text(
                      _selectedServiceName!,
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _isLoadingCountries
              ? Center(child: CircularProgressIndicator(color: accentBlue))
              : _countries.isEmpty
                  ? Center(
                      child: Text(
                        'No countries available',
                        style: TextStyle(color: Colors.white60),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _countries.length,
                      itemBuilder: (context, index) {
                        final country = _countries[index];
                        final isSelected = _selectedCountry?['id'] == country['id'];
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? accentBlue.withOpacity(0.2) 
                                : cardDarker,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected 
                                  ? accentBlue 
                                  : Colors.white10,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _selectedCountry = country;
                              });
                              Navigator.pop(context);
                              if (_selectedServiceCode != null) {
                                _loadPrices(
                                  _selectedServiceCode!,
                                  country['id'],
                                  country['name'],
                                );
                              }
                            },
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accentBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.flag,
                                color: accentBlue,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              country['name'] ?? 'Unknown',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Stock: ${country['stock']}',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: accentBlue)
                                : Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
                          ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  void _showPricesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.attach_money, color: goldColor, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Price',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  if (_selectedCountry != null)
                    Text(
                      _selectedCountry!['name'],
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _isLoadingPrices
              ? Center(child: CircularProgressIndicator(color: accentBlue))
              : _prices.isEmpty
                  ? Center(
                      child: Text(
                        'No prices available',
                        style: TextStyle(color: Colors.white60),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _prices.length,
                      itemBuilder: (context, index) {
                        final price = _prices[index];
                        final isSelected = _selectedPrice?['providerId'] == price['providerId'];
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? goldColor.withOpacity(0.2) 
                                : cardDarker,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected 
                                  ? goldColor 
                                  : Colors.white10,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _selectedPrice = price;
                              });
                              Navigator.pop(context);
                            },
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: goldColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_offer,
                                color: goldColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              price['displayPrice'] ?? 'Unknown',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  price['serverName'] ?? 'Server 3',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  'Stock: ${price['stock']}',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: goldColor)
                                : Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
                          ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🎨 UI BUILDERS
  // ==========================================

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildProfileHeader() {
    return _buildGlassCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop Balance',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  _isLoadingProfile
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: goldColor,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _profileData?['displayBalance'] ?? 'Rp 0',
                          style: TextStyle(
                            color: goldColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: goldColor,
                  size: 32,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: Colors.white10),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.shopping_bag,
                'Orders',
                _profileData?['totalOrders']?.toString() ?? '0',
                accentBlue,
              ),
              Container(height: 40, width: 1, color: Colors.white10),
              _buildStatItem(
                Icons.receipt_long,
                'Deposits',
                _profileData?['totalDeposits']?.toString() ?? '0',
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBuyTab() {
    return Column(
      children: [
        _buildProfileHeader(),
        
        // Order Summary Card
        if (_selectedServiceCode != null || _selectedCountry != null || _selectedPrice != null)
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetSelection,
                      icon: Icon(Icons.clear, size: 16),
                      label: Text('Reset'),
                      style: TextButton.styleFrom(
                        foregroundColor: accentRed,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (_selectedServiceName != null) ...[
                  _buildSummaryItem(
                    Icons.apps,
                    'Service',
                    _selectedServiceName!,
                    accentBlue,
                  ),
                  SizedBox(height: 8),
                ],
                if (_selectedCountry != null) ...[
                  _buildSummaryItem(
                    Icons.public,
                    'Country',
                    _selectedCountry!['name'],
                    accentBlue,
                  ),
                  SizedBox(height: 8),
                ],
                if (_selectedPrice != null) ...[
                  _buildSummaryItem(
                    Icons.attach_money,
                    'Price',
                    _selectedPrice!['displayPrice'],
                    goldColor,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_checkout, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Place Order',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        
        // Selection Buttons
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Options',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildSelectionButton(
                icon: Icons.apps,
                label: 'Select Service',
                value: _selectedServiceName,
                onTap: () {
                  // Show services list
                  setState(() => _currentTabIndex = 0);
                },
                color: accentBlue,
              ),
              if (_selectedServiceCode != null) ...[
                SizedBox(height: 8),
                _buildSelectionButton(
                  icon: Icons.public,
                  label: 'Select Country',
                  value: _selectedCountry?['name'],
                  onTap: _showCountriesDialog,
                  color: accentBlue,
                  isLoading: _isLoadingCountries,
                ),
              ],
              if (_selectedCountry != null) ...[
                SizedBox(height: 8),
                _buildSelectionButton(
                  icon: Icons.attach_money,
                  label: 'Select Price',
                  value: _selectedPrice?['displayPrice'],
                  onTap: _showPricesDialog,
                  color: goldColor,
                  isLoading: _isLoadingPrices,
                ),
              ],
            ],
          ),
        ),
        
        // Services List
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search services...',
                    hintStyle: TextStyle(color: Colors.white60),
                    prefixIcon: Icon(Icons.search, color: Colors.white60),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white60),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _isLoadingServices
              ? Center(child: CircularProgressIndicator(color: accentBlue))
              : _filteredServices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, color: Colors.white30, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'No services found',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredServices.length,
                      itemBuilder: (context, index) {
                        final service = _filteredServices[index];
                        final isSelected = _selectedServiceCode == service['code'];
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? accentBlue.withOpacity(0.2) 
                                : cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? accentBlue 
                                  : Colors.white10,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              _loadCountries(
                                service['code'],
                                service['name'],
                              );
                            },
                            leading: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.apps,
                                color: accentBlue,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              service['name'] ?? 'Unknown Service',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              service['code'] ?? '',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: accentBlue)
                                : Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
                          ),
                        );
                      },
                    ),
        ),
        
        // Pagination
        if (_totalPages > 1)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardDark,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _hasPrevPage 
                      ? () => _loadServices(page: _currentPage - 1)
                      : null,
                  icon: Icon(Icons.arrow_back, size: 16),
                  label: Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasPrevPage ? accentBlue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: TextStyle(color: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: _hasNextPage 
                      ? () => _loadServices(page: _currentPage + 1)
                      : null,
                  icon: Icon(Icons.arrow_forward, size: 16),
                  label: Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasNextPage ? accentBlue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionButton({
    required IconData icon,
    required String label,
    String? value,
    required VoidCallback onTap,
    required Color color,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  if (value != null)
                    Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.8), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_orders.isEmpty && !_isLoadingOrders) {
      // Load orders on first view
      Future.delayed(Duration.zero, _loadOrders);
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: accentBlue,
      backgroundColor: cardDark,
      child: _isLoadingOrders
          ? Center(child: CircularProgressIndicator(color: accentBlue))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, color: Colors.white30, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'No orders yet',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return _buildOrderCard(order);
                  },
                ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status']?.toString().toLowerCase() ?? 'pending';
    final canRefund = status == 'pending';
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Text(
                  order['timestamp'] ?? '',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderInfoRow('Order ID', order['orderId'] ?? '-'),
                SizedBox(height: 8),
                _buildOrderInfoRow('Phone Number', order['phoneNumber'] ?? '-', 
                  isCopyable: true,
                  copyValue: order['phoneNumber'],
                ),
                SizedBox(height: 8),
                _buildOrderInfoRow('Country', order['country'] ?? '-'),
                SizedBox(height: 8),
                _buildOrderInfoRow('Price', order['displayPrice'] ?? '-'),
                
                SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _checkOTP(order['orderId']),
                        icon: Icon(Icons.message, size: 16),
                        label: Text('Check OTP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (canRefund) ...[
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _refundOrder(order['orderId']),
                          icon: Icon(Icons.restore, size: 16),
                          label: Text('Refund'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentRed,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoRow(String label, String value, {bool isCopyable = false, String? copyValue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isCopyable && copyValue != null) ...[
              SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: copyValue));
                  _showSuccessSnackbar('Copied to clipboard');
                },
                child: Icon(
                  Icons.copy,
                  size: 14,
                  color: accentBlue,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'refunded':
        return Icons.restore;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Widget _buildDepositsTab() {
    if (_deposits.isEmpty && !_isLoadingDeposits) {
      // Load deposits on first view
      Future.delayed(Duration.zero, _loadDeposits);
    }

    return RefreshIndicator(
      onRefresh: _loadDeposits,
      color: accentBlue,
      backgroundColor: cardDark,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showDepositDialog,
                icon: Icon(Icons.add_circle, size: 20),
                label: Text(
                  'New Deposit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldColor,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoadingDeposits
                ? Center(child: CircularProgressIndicator(color: accentBlue))
                : _deposits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, color: Colors.white30, size: 64),
                            SizedBox(height: 16),
                            Text(
                              'No deposits yet',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _deposits.length,
                        itemBuilder: (context, index) {
                          final deposit = _deposits[index];
                          return _buildDepositCard(deposit);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositCard(Map<String, dynamic> deposit) {
    final status = deposit['status']?.toString().toLowerCase() ?? 'pending';
    final isPending = status == 'pending';
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Text(
                  deposit['createdAt'] ?? '',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderInfoRow('Order ID', deposit['orderId'] ?? '-'),
                SizedBox(height: 8),
                _buildOrderInfoRow('Amount', deposit['displayAmount'] ?? '-'),
                if (deposit['completedAt'] != null) ...[
                  SizedBox(height: 8),
                  _buildOrderInfoRow('Completed', deposit['completedAt'] ?? '-'),
                ],
                
                if (isPending) ...[
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _checkDepositStatus(deposit['orderId']),
                      icon: Icon(Icons.refresh, size: 16),
                      label: Text('Check Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildGlassCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: cardDarker,
                  child: Icon(Icons.person, color: Colors.white60, size: 40),
                ),
                SizedBox(height: 16),
                Text(
                  widget.username,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentBlue.withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.role.toUpperCase(),
                    style: TextStyle(
                      color: accentBlue,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildProfileHeader(),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                _buildActionButton(
                  icon: Icons.add_circle,
                  label: 'Deposit',
                  color: goldColor,
                  onTap: _showDepositDialog,
                ),
                SizedBox(height: 8),
                _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Refresh Balance',
                  color: accentBlue,
                  onTap: _loadProfile,
                ),
              ],
            ),
          ),
          if (_configData != null)
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow('Min Deposit', _configData!['display_min_deposit'] ?? '-'),
                  _buildInfoRow('Price Markup', 'Rp ${_formatNumber(_configData!['markup_harga'])}'),
                  _buildInfoRow('Refund Delay', '${_configData!['refund_delay_minutes']} minutes'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.8), size: 16),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'refunded':
        return accentRed;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Row(
          children: [
            Icon(Icons.phone_android, color: accentBlue, size: 24),
            SizedBox(width: 12),
            Text(
              'Nokos Shop',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.95),
              Colors.black,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildCurrentPage(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.shopping_cart,
                  label: 'Buy',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.receipt,
                  label: 'Orders',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.history,
                  label: 'Deposits',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
        // Load data when switching tabs
        if (index == 1 && _orders.isEmpty) {
          _loadOrders();
        } else if (index == 2 && _deposits.isEmpty) {
          _loadDeposits();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentBlue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? accentBlue : Colors.white60,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accentBlue : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentTabIndex) {
      case 0:
        return _buildBuyTab();
      case 1:
        return _buildOrdersTab();
      case 2:
        return _buildDepositsTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildBuyTab();
    }
  }
}
