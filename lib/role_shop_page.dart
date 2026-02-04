import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart'; // ✅ ADD THIS PACKAGE

/// 🛒 ROLE SHOP WITH BALANCE SYSTEM
/// Sistem pembelian role menggunakan saldo user
/// 
/// API Endpoints:
/// ✅ GET  /api/balance/:username      - Get user balance
/// ✅ POST /api/balance/topup/create   - Create top up order
/// ✅ POST /api/balance/topup/verify   - Verify top up payment  
/// ✅ GET  /api/transactions/:username - Get transaction history
/// ✅ GET  /api/deposits/:username     - Get deposit orders
/// ✅ POST /api/roles/purchase         - Purchase role with balance
/// ✅ DELETE /api/deposits/:order_id   - Cancel deposit

class RoleShopBalancePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final String role;
  final String expiredDate;

  const RoleShopBalancePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<RoleShopBalancePage> createState() => _RoleShopBalancePageState();
}

class _RoleShopBalancePageState extends State<RoleShopBalancePage> with SingleTickerProviderStateMixin {
  // ==========================================
  // 🎨 THEME COLORS
  // ==========================================
  final Color primaryDark = const Color(0xFF000000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF0D0D0D);
  final Color accentRed = const Color(0xFFDC143C);
  final Color accentBlue = const Color(0xFF2196F3);
  final Color goldColor = const Color(0xFFFFD700);
  final Color accentGreen = const Color(0xFF4CAF50);
  final Color accentPurple = const Color(0xFF9C27B0);

  // ==========================================
  // 🌐 API CONFIGURATION
  // ==========================================
  final String baseUrl = 'https://tapops.fanzhosting.my.id';

  // ==========================================
  // 📊 STATE VARIABLES
  // ==========================================
  
  // Navigation
  int _currentTabIndex = 0;
  
  // Balance
  int _balance = 0;
  bool _isLoadingBalance = true;
  
  // Role Catalog
  List<Map<String, dynamic>> _roles = [];
  bool _isLoadingRoles = true;
  
  // ✅ MIN TOPUP from backend
  int _minTopup = 1000;
  
  // Transactions
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingTransactions = false;
  
  // Deposits
  List<Map<String, dynamic>> _deposits = [];
  bool _isLoadingDeposits = false;
  
  // Current Top Up
  Map<String, dynamic>? _currentTopUp;
  bool _isCreatingTopUp = false;
  bool _isVerifyingPayment = false;
  Timer? _autoCheckTimer;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // ✅ Carousel controller
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentCarouselIndex = 0;

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
    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  // ==========================================
  // 🔄 DATA LOADING
  // ==========================================

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadBalance(),
      _loadRoleCatalog(),
    ]);
  }

  // ✨ ENHANCED REFRESH WITH BETTER FEEDBACK
  Future<void> _refreshAll() async {
    HapticFeedback.mediumImpact(); // Haptic feedback saat pull to refresh
    
    final previousBalance = _balance;
    
    await Future.wait([
      _loadBalance(),
      if (_currentTabIndex == 1) _loadTransactions(),
      if (_currentTabIndex == 2) _loadDeposits(),
    ]);
    
    // Show smart feedback
    if (_currentTabIndex == 0 && _balance != previousBalance) {
      if (_balance > previousBalance) {
        _showSuccessSnackbar('Balance updated! +Rp ${_formatNumber(_balance - previousBalance)}');
      } else if (_balance < previousBalance) {
        _showInfoSnackbar('Balance updated: Rp ${_formatNumber(_balance)}');
      }
    }
  }

  // ✨ AUTO REFRESH when returning to this page
  @override
  void didUpdateWidget(RoleShopBalancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto refresh balance when widget updates
    _loadBalance();
  }

  // ==========================================
  // 🌐 API IMPLEMENTATION
  // ==========================================

  /// ✅ GET /api/balance/:username
  Future<void> _loadBalance() async {
    setState(() => _isLoadingBalance = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/balance/${widget.username}'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _balance = data['data']['balance'] ?? 0;
          // ✅ GET min_topup from API response
          _minTopup = data['data']['min_topup'] ?? 1000;
          _isLoadingBalance = false;
        });
        debugPrint('✅ Balance loaded: $_balance, min_topup: $_minTopup');
      } else {
        setState(() => _isLoadingBalance = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to load balance');
      }
    } catch (e) {
      debugPrint('❌ Error loading balance: $e');
      setState(() => _isLoadingBalance = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ GET /api/roles
  Future<void> _loadRoleCatalog() async {
    setState(() => _isLoadingRoles = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/roles'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _roles = List<Map<String, dynamic>>.from(data['data']);
          _isLoadingRoles = false;
        });
        debugPrint('✅ Roles loaded: ${_roles.length}');
      } else {
        setState(() => _isLoadingRoles = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to load roles');
      }
    } catch (e) {
      debugPrint('❌ Error loading roles: $e');
      setState(() => _isLoadingRoles = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ GET /api/transactions/:username - FIX LOADING ISSUE
  Future<void> _loadTransactions() async {
    if (_isLoadingTransactions) return; // Prevent duplicate loading
    
    setState(() => _isLoadingTransactions = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/transactions/${widget.username}?limit=50'),
      ).timeout(Duration(seconds: 10)); // Add timeout

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoadingTransactions = false;
        });
        debugPrint('✅ Transactions loaded: ${_transactions.length}');
      } else {
        setState(() {
          _transactions = [];
          _isLoadingTransactions = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading transactions: $e');
      setState(() {
        _transactions = [];
        _isLoadingTransactions = false;
      });
    }
  }

  /// ✅ GET /api/deposits/:username - FIX LOADING ISSUE
  Future<void> _loadDeposits() async {
    if (_isLoadingDeposits) return; // Prevent duplicate loading
    
    setState(() => _isLoadingDeposits = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/deposits/${widget.username}'),
      ).timeout(Duration(seconds: 10)); // Add timeout

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _deposits = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoadingDeposits = false;
        });
        debugPrint('✅ Deposits loaded: ${_deposits.length}');
      } else {
        setState(() {
          _deposits = [];
          _isLoadingDeposits = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading deposits: $e');
      setState(() {
        _deposits = [];
        _isLoadingDeposits = false;
      });
    }
  }

  /// ✅ POST /api/balance/topup/create
  Future<void> _createTopUp(int amount) async {
    setState(() => _isCreatingTopUp = true);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/balance/topup/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': widget.username,
          'amount': amount,
        }),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _currentTopUp = data['data'];
          _isCreatingTopUp = false;
        });
        
        debugPrint('✅ Top up created: ${data['data']}');
        
        // Show QR dialog
        _showQRDialog();
        
        // Start auto-check timer (every 3 seconds)
        _startAutoCheckPayment();
        
      } else {
        setState(() => _isCreatingTopUp = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to create top up');
      }
    } catch (e) {
      debugPrint('❌ Error creating top up: $e');
      setState(() => _isCreatingTopUp = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ POST /api/balance/topup/verify
  Future<void> _verifyPayment() async {
    if (_currentTopUp == null) return;
    
    setState(() => _isVerifyingPayment = true);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/balance/topup/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'order_id': _currentTopUp!['order_id'],
          'username': widget.username,
        }),
      );

      final data = json.decode(response.body);
      
      setState(() => _isVerifyingPayment = false);
      
      if (data['success'] == true) {
        debugPrint('✅ Payment verified!');
        
        // Stop auto-check
        _autoCheckTimer?.cancel();
        
        // Close QR dialog
        Navigator.pop(context);
        
        // Show success
        _showSuccessSnackbar('Top up successful! +Rp ${_formatNumber(_currentTopUp!['amount'])}');
        
        // Reload balance
        await _loadBalance();
        
        // Clear current top up
        setState(() => _currentTopUp = null);
        
      } else {
        if (data['message']?.contains('pending') == true) {
          // Still pending, auto-check will continue
          debugPrint('⏳ Payment still pending...');
        } else {
          _showErrorSnackbar(data['message'] ?? 'Payment verification failed');
        }
      }
    } catch (e) {
      debugPrint('❌ Error verifying payment: $e');
      setState(() => _isVerifyingPayment = false);
    }
  }

  /// ✅ Auto-check payment status
  void _startAutoCheckPayment() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (_currentTopUp != null) {
        _verifyPayment();
      } else {
        timer.cancel();
      }
    });
  }

  /// ✅ POST /api/roles/purchase
  Future<void> _purchaseRole(Map<String, dynamic> role) async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Purchase', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase ${role['role_name']} role?',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardDarker,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Price', 'Rp ${_formatNumber(role['price'])}', accentRed),
                  _buildInfoRow('Duration', '${role['duration_days']} days', Colors.white),
                  _buildInfoRow('Your Balance', 'Rp ${_formatNumber(_balance)}', accentGreen),
                  Divider(color: Colors.white24, height: 20),
                  _buildInfoRow(
                    'After Purchase',
                    'Rp ${_formatNumber(_balance - role['price'])}',
                    _balance >= role['price'] ? accentGreen : accentRed,
                  ),
                ],
              ),
            ),
            if (_balance < role['price']) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: accentRed, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient balance!',
                        style: TextStyle(color: accentRed, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: _balance >= role['price'] 
              ? () => Navigator.pop(context, true)
              : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: goldColor,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey,
            ),
            child: Text('Purchase'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: goldColor),
              SizedBox(height: 16),
              Text(
                'Processing purchase...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/roles/purchase'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': widget.username,
          'role_id': role['role_id'],
        }),
      );

      final data = json.decode(response.body);
      
      // Close loading
      Navigator.pop(context);
      
      if (data['success'] == true) {
        debugPrint('✅ Role purchased successfully!');
        
        // Reload balance
        await _loadBalance();
        
        // Show success dialog
        _showPurchaseSuccessDialog(data['data']);
        
      } else {
        _showErrorSnackbar(data['message'] ?? 'Purchase failed');
      }
    } catch (e) {
      // Close loading
      Navigator.pop(context);
      debugPrint('❌ Error purchasing role: $e');
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ DELETE /api/deposits/:order_id
  Future<void> _cancelDeposit(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Deposit?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to cancel this deposit order?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: accentRed),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/deposits/$orderId'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        _showSuccessSnackbar('Deposit cancelled');
        await _loadDeposits();
      } else {
        _showErrorSnackbar(data['message'] ?? 'Failed to cancel deposit');
      }
    } catch (e) {
      debugPrint('❌ Error cancelling deposit: $e');
      _showErrorSnackbar('Network error: $e');
    }
  }

  // ==========================================
  // 🎨 UI COMPONENTS
  // ==========================================

  Widget _buildCurrentPage() {
    switch (_currentTabIndex) {
      case 0:
        return _buildShopPage();
      case 1:
        return _buildHistoryPage();
      case 2:
        return _buildDepositsPage();
      default:
        return _buildShopPage();
    }
  }

  // ==========================================
  // 🛍️ SHOP PAGE
  // ==========================================

  Widget _buildShopPage() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: goldColor,
      backgroundColor: cardDark,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ IMPROVED BALANCE CARD - Modern & Simple (No Glow Effect)
              _buildModernBalanceCard(),
              
              SizedBox(height: 24),
              
              // ✅ CAROUSEL ROLE CARDS
              _buildRoleCarousel(),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Modern Balance Card (No Glow Effect)
  Widget _buildModernBalanceCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardDark,
            cardDarker,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: goldColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Balance',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  _isLoadingBalance
                    ? ShimmerLoading(
                        child: Container(
                          width: 150,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : Text(
                        'Rp ${_formatNumber(_balance)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
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
          
          // Top Up Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTopUpDialog(),
              icon: Icon(Icons.add_circle_outline, size: 20),
              label: Text(
                'Top Up Balance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: goldColor,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Role Carousel with Cards
  Widget _buildRoleCarousel() {
    if (_isLoadingRoles) {
      return Column(
        children: [
          ShimmerLoading(
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      );
    }

    if (_roles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text(
                'No roles available',
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Roles',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_currentCarouselIndex + 1}/${_roles.length}',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        CarouselSlider.builder(
          carouselController: _carouselController,
          itemCount: _roles.length,
          options: CarouselOptions(
            height: 450,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            viewportFraction: 0.85,
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
          ),
          itemBuilder: (context, index, realIndex) {
            final role = _roles[index];
            return _buildRoleCard(role);
          },
        ),
        
        SizedBox(height: 16),
        
        // Carousel indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _roles.asMap().entries.map((entry) {
            return Container(
              width: _currentCarouselIndex == entry.key ? 24 : 8,
              height: 8,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _currentCarouselIndex == entry.key
                  ? goldColor
                  : Colors.white24,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ✅ IMPROVED: Role Card with Full Description from ROLE_CATALOG
  Widget _buildRoleCard(Map<String, dynamic> role) {
    final isCurrentRole = widget.role.toLowerCase() == role['role_id'].toLowerCase();
    
    // Role-specific styling
    Color getRoleColor() {
      switch (role['role_id'].toLowerCase()) {
        case 'member': return accentBlue;
        case 'vip': return accentPurple;
        case 'reseller': return accentGreen;
        default: return goldColor;
      }
    }
    
    // ✅ Get full description from role data
    final description = role['description'] ?? 'No description available';
    final features = List<String>.from(role['features'] ?? []);
    
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardDark,
            cardDarker,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentRole 
            ? goldColor 
            : getRoleColor().withOpacity(0.3),
          width: isCurrentRole ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: getRoleColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role['role_name'] ?? role['role_id'],
                        style: TextStyle(
                          color: getRoleColor(),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isCurrentRole) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: goldColor, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Current Role',
                            style: TextStyle(
                              color: goldColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.workspace_premium,
                color: getRoleColor(),
                size: 40,
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // ✅ Description from ROLE_CATALOG
          Text(
            description,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          SizedBox(height: 16),
          
          // ✅ Features from ROLE_CATALOG
          if (features.isNotEmpty) ...[
            Text(
              'Features:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            ...features.take(3).map((feature) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: getRoleColor(),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            if (features.length > 3)
              Padding(
                padding: EdgeInsets.only(left: 24),
                child: Text(
                  '+${features.length - 3} more features',
                  style: TextStyle(
                    color: getRoleColor(),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            SizedBox(height: 16),
          ],
          
          // Price & Duration
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardDarker,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    Text(
                      'Rp ${_formatNumber(role['price'])}',
                      style: TextStyle(
                        color: getRoleColor(),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    Text(
                      '${role['duration_days']} days',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Spacer(),
          
          // Purchase Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrentRole ? null : () => _purchaseRole(role),
              style: ElevatedButton.styleFrom(
                backgroundColor: getRoleColor(),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                isCurrentRole ? 'Current Role' : 'Purchase Now',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 📜 HISTORY PAGE
  // ==========================================

  Widget _buildHistoryPage() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadTransactions();
      },
      color: goldColor,
      backgroundColor: cardDark,
      child: _isLoadingTransactions
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: goldColor),
                SizedBox(height: 16),
                Text(
                  'Loading transactions...',
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          )
        : _transactions.isEmpty
          ? ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 100),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final transaction = _transactions[index];
                return _buildTransactionCard(transaction);
              },
            ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final type = transaction['type'] ?? '';
    final amount = transaction['amount'] ?? 0;
    final createdAt = transaction['created_at'] ?? '';
    
    IconData icon;
    Color color;
    
    if (type == 'topup') {
      icon = Icons.add_circle;
      color = accentGreen;
    } else if (type == 'purchase') {
      icon = Icons.shopping_bag;
      color = accentRed;
    } else {
      icon = Icons.swap_horiz;
      color = accentBlue;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          
          SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description'] ?? type.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatDateTime(createdAt),
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          Text(
            '${type == 'topup' ? '+' : '-'}Rp ${_formatNumber(amount)}',
            style: TextStyle(
              color: type == 'topup' ? accentGreen : accentRed,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 📦 DEPOSITS PAGE
  // ==========================================

  Widget _buildDepositsPage() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadDeposits();
      },
      color: goldColor,
      backgroundColor: cardDark,
      child: _isLoadingDeposits
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: goldColor),
                SizedBox(height: 16),
                Text(
                  'Loading deposits...',
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          )
        : _deposits.isEmpty
          ? ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 100),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'No pending deposits',
                        style: TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              itemCount: _deposits.length,
              itemBuilder: (context, index) {
                final deposit = _deposits[index];
                return _buildDepositCard(deposit);
              },
            ),
    );
  }

  Widget _buildDepositCard(Map<String, dynamic> deposit) {
    final status = deposit['status'] ?? 'pending';
    final amount = deposit['amount'] ?? 0;
    final createdAt = deposit['created_at'] ?? '';
    final orderId = deposit['order_id'] ?? '';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = accentGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'cancelled':
        statusColor = accentRed;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 20),
                        SizedBox(width: 8),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Rp ${_formatNumber(amount)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatDateTime(createdAt),
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (status == 'pending')
                IconButton(
                  onPressed: () => _cancelDeposit(orderId),
                  icon: Icon(Icons.close, color: accentRed),
                  tooltip: 'Cancel',
                ),
            ],
          ),
          
          if (status == 'pending') ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentTopUp = deposit;
                  });
                  _showQRDialog();
                  _startAutoCheckPayment();
                },
                icon: Icon(Icons.qr_code, size: 18),
                label: Text('Show QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 💳 TOP UP DIALOG
  // ==========================================

  void _showTopUpDialog() {
    final TextEditingController amountController = TextEditingController();
    
    // ✅ BLUR BACKGROUND EFFECT
    showDialog(
      context: context,
      barrierColor: Colors.black87, // Darker barrier
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // ✅ BLUR EFFECT
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: goldColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: goldColor, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Top Up Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // ✅ Show minimum topup
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: accentBlue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Minimum top up: Rp ${_formatNumber(_minTopup)}',
                          style: TextStyle(
                            color: accentBlue,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
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
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: goldColor),
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Quick amount buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [10000, 20000, 50000, 100000].map((amount) {
                    return InkWell(
                      onTap: () {
                        amountController.text = amount.toString();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardDarker,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: goldColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Rp ${_formatNumber(amount)}',
                          style: TextStyle(
                            color: goldColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final amount = int.tryParse(amountController.text) ?? 0;
                          
                          // ✅ Validate minimum topup
                          if (amount < _minTopup) {
                            _showErrorSnackbar('Minimum top up is Rp ${_formatNumber(_minTopup)}');
                            return;
                          }
                          
                          Navigator.pop(context);
                          _createTopUp(amount);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 📱 QR CODE DIALOG
  // ==========================================

  void _showQRDialog() {
    if (_currentTopUp == null) return;
    
    final qrImage = _currentTopUp!['qr_image'];
    final amount = _currentTopUp!['amount'];
    final orderId = _currentTopUp!['order_id'];
    
    // ✅ BLUR BACKGROUND EFFECT
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          _autoCheckTimer?.cancel();
          setState(() => _currentTopUp = null);
          return true;
        },
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // ✅ BLUR EFFECT
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: goldColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scan QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _autoCheckTimer?.cancel();
                          setState(() => _currentTopUp = null);
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.close, color: Colors.white60),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: qrImage != null
                      ? Image.memory(
                          base64Decode(qrImage.split(',').last),
                          width: 250,
                          height: 250,
                          fit: BoxFit.contain,
                        )
                      : Container(
                          width: 250,
                          height: 250,
                          child: Center(
                            child: Text('QR Code not available'),
                          ),
                        ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardDarker,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Amount', 'Rp ${_formatNumber(amount)}', goldColor),
                        _buildInfoRow('Order ID', orderId, Colors.white),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  if (_isVerifyingPayment)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: goldColor,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Checking payment...',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: accentGreen, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment will be verified automatically',
                              style: TextStyle(
                                color: accentGreen,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifyingPayment ? null : _verifyPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Check Payment Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ✅ SUCCESS DIALOG
  // ==========================================

  void _showPurchaseSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.workspace_premium, color: goldColor, size: 64),
            SizedBox(height: 16),
            Text(
              'Purchase Success!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You now have ${data['role']} role!',
              style: TextStyle(
                color: goldColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardDarker,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Expired', data['expired_date'] ?? '', Colors.white),
                  _buildInfoRow(
                    'Remaining Balance',
                    'Rp ${_formatNumber(data['new_balance'] ?? 0)}',
                    accentGreen,
                  ),
                ],
              ),
            ),
            if (data['group_link'] != null) ...[
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(data['group_link']);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: Icon(Icons.group),
                label: Text('Join Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Reload to refresh UI
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: goldColor,
              foregroundColor: Colors.black,
            ),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🛠️ HELPER METHODS
  // ==========================================

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(num number) {
    return number.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accentRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accentBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            Icon(Icons.store, color: goldColor, size: 24),
            SizedBox(width: 12),
            Text(
              'Role Shop',
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.shopping_bag, label: 'Shop', index: 0),
                _buildNavItem(icon: Icons.receipt, label: 'History', index: 1),
                _buildNavItem(icon: Icons.inventory, label: 'Deposits', index: 2),
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
        // ✅ FIX: Load data only once when switching tabs
        if (index == 1 && _transactions.isEmpty && !_isLoadingTransactions) {
          _loadTransactions();
        } else if (index == 2 && _deposits.isEmpty && !_isLoadingDeposits) {
          _loadDeposits();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? goldColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? goldColor : Colors.white60,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? goldColor : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ✨ SHIMMER LOADING WIDGET
// ==========================================

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white10,
                Colors.white24,
                Colors.white10,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
