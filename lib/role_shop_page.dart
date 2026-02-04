import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
          _isLoadingBalance = false;
        });
        debugPrint('✅ Balance loaded: $_balance');
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

  /// ✅ GET /api/transactions/:username
  Future<void> _loadTransactions() async {
    setState(() => _isLoadingTransactions = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/transactions/${widget.username}?limit=50'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(data['data']);
          _isLoadingTransactions = false;
        });
        debugPrint('✅ Transactions loaded: ${_transactions.length}');
      } else {
        setState(() => _isLoadingTransactions = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading transactions: $e');
      setState(() => _isLoadingTransactions = false);
    }
  }

  /// ✅ GET /api/deposits/:username
  Future<void> _loadDeposits() async {
    setState(() => _isLoadingDeposits = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/deposits/${widget.username}'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _deposits = List<Map<String, dynamic>>.from(data['data']);
          _isLoadingDeposits = false;
        });
        debugPrint('✅ Deposits loaded: ${_deposits.length}');
      } else {
        setState(() => _isLoadingDeposits = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading deposits: $e');
      setState(() => _isLoadingDeposits = false);
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
        
        debugPrint('✅ Top up created: ${data['data']['order_id']}');
        
        // Start auto check
        _startAutoCheckPayment();
        
        // Show QRIS dialog
        _showQRISDialog();
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
  Future<void> _verifyTopUp(String orderId) async {
    setState(() => _isVerifyingPayment = true);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/balance/topup/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'order_id': orderId,
          'username': widget.username,
        }),
      );

      final data = json.decode(response.body);
      
      setState(() => _isVerifyingPayment = false);
      
      if (data['success'] == true) {
        if (data['data']['status'] == 'completed') {
          // Payment verified!
          _stopAutoCheckPayment();
          
          setState(() {
            _currentTopUp = null;
          });
          
          // Close dialog
          Navigator.of(context).pop();
          
          // Reload balance
          await _loadBalance();
          
          // Show success
          _showSuccessDialog(data['data']);
        } else {
          _showInfoSnackbar('Payment not detected yet');
        }
      } else {
        _showErrorSnackbar(data['message'] ?? 'Payment verification failed');
      }
    } catch (e) {
      debugPrint('❌ Error verifying payment: $e');
      setState(() => _isVerifyingPayment = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ POST /api/roles/purchase
  Future<void> _purchaseRole(Map<String, dynamic> role) async {
    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmDialog(role),
    );
    
    if (confirmed != true) return;
    
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
      
      if (data['success'] == true) {
        // Reload balance
        await _loadBalance();
        
        // Show success with group link
        _showPurchaseSuccessDialog(data['data']);
      } else {
        _showErrorSnackbar(data['message'] ?? 'Purchase failed');
      }
    } catch (e) {
      debugPrint('❌ Error purchasing role: $e');
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ DELETE /api/deposits/:order_id
  Future<void> _cancelDeposit(String orderId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/deposits/$orderId?username=${widget.username}'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        _showSuccessSnackbar('Deposit cancelled');
        _loadDeposits();
      } else {
        _showErrorSnackbar(data['message'] ?? 'Failed to cancel');
      }
    } catch (e) {
      debugPrint('❌ Error cancelling deposit: $e');
      _showErrorSnackbar('Network error: $e');
    }
  }

  // ==========================================
  // ⏰ AUTO CHECK PAYMENT
  // ==========================================

  void _startAutoCheckPayment() {
    _autoCheckTimer?.cancel();
    
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentTopUp != null) {
        _verifyTopUp(_currentTopUp!['order_id']);
      } else {
        timer.cancel();
      }
    });
  }

  void _stopAutoCheckPayment() {
    _autoCheckTimer?.cancel();
  }

  // ==========================================
  // 🎨 UI BUILDERS - TABS
  // ==========================================

  Widget _buildCurrentPage() {
    switch (_currentTabIndex) {
      case 0:
        return _buildShopTab();
      case 1:
        return _buildTransactionsTab();
      case 2:
        return _buildDepositsTab();
      default:
        return _buildShopTab();
    }
  }

  // ==========================================
  // 🛍️ SHOP TAB
  // ==========================================

  Widget _buildShopTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: goldColor,
      backgroundColor: cardDark,
      strokeWidth: 3.0,
      displacement: 40.0, // Distance to trigger refresh
      // ✨ Custom notification when refreshing
      notificationPredicate: (ScrollNotification notification) {
        return notification.depth == 0;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(), // ✨ iOS-style bounce
        ),
        slivers: [
          // ✨ PULL TO REFRESH HINT
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 14,
                      color: Colors.white24,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Pull to refresh',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Balance Card
          SliverToBoxAdapter(
            child: _buildBalanceCard(),
          ),
          
          // Top Up Button
          SliverToBoxAdapter(
            child: _buildTopUpButton(),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                '✨ Available Roles',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          
          // Role Cards
          if (_isLoadingRoles)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: goldColor),
                ),
              ),
            )
          else if (_roles.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No roles available',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildRoleCard(_roles[index]),
                childCount: _roles.length,
              ),
            ),
          
          SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [goldColor.withOpacity(0.3), goldColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: goldColor.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: goldColor, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isLoadingBalance)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Refreshing...',
                          style: TextStyle(
                            color: goldColor.withOpacity(0.7),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ✨ ENHANCED REFRESH BUTTON
              Container(
                decoration: BoxDecoration(
                  color: _isLoadingBalance 
                      ? goldColor.withOpacity(0.1) 
                      : goldColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: goldColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isLoadingBalance ? null : _handleRefreshBalance,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _isLoadingBalance
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: goldColor,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: goldColor,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // ✨ BALANCE AMOUNT WITH ANIMATION
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              'Rp ${_formatNumber(_balance)}',
              key: ValueKey<int>(_balance), // Key untuk trigger animation
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          // ✨ LAST UPDATED INFO
          if (!_isLoadingBalance)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Colors.white38,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Tap refresh to update',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✨ ENHANCED REFRESH HANDLER
  Future<void> _handleRefreshBalance() async {
    // Haptic feedback (if available)
    HapticFeedback.lightImpact();
    
    final previousBalance = _balance;
    
    await _loadBalance();
    
    // Show feedback based on balance change
    if (_balance > previousBalance) {
      _showSuccessSnackbar('Balance increased! +Rp ${_formatNumber(_balance - previousBalance)}');
    } else if (_balance < previousBalance) {
      _showInfoSnackbar('Balance updated: Rp ${_formatNumber(_balance)}');
    } else {
      _showInfoSnackbar('Balance is up to date');
    }
  }

  Widget _buildTopUpButton() {
    return GestureDetector(
      onTap: _showTopUpDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: accentBlue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentBlue.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, color: accentBlue, size: 24),
            SizedBox(width: 12),
            Text(
              'Top Up Balance',
              style: TextStyle(
                color: accentBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role) {
    final price = role['price'] ?? 0;
    final canAfford = _balance >= price;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canAfford ? goldColor.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: canAfford
            ? [
                BoxShadow(
                  color: goldColor.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.workspace_premium, color: goldColor, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role['role_name'] ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${role['duration_days']} days access',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          Divider(color: Colors.white24),
          SizedBox(height: 16),
          
          if (role['features'] != null && role['features'].isNotEmpty)
            ...List<Widget>.from(
              (role['features'] as List).map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: accentGreen, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
            ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rp ${_formatNumber(price)}',
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: canAfford ? () => _purchaseRole(role) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? goldColor : Colors.grey,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 18),
                    SizedBox(width: 8),
                    Text(
                      canAfford ? 'Purchase' : 'Insufficient',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 📜 TRANSACTIONS TAB
  // ==========================================

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty && !_isLoadingTransactions) {
      _loadTransactions();
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await _loadTransactions();
        _showInfoSnackbar('Transactions updated');
      },
      color: goldColor,
      backgroundColor: cardDark,
      strokeWidth: 3.0,
      child: _isLoadingTransactions
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: goldColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading transactions...',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            )
          : _transactions.isEmpty
              ? ListView(
                  physics: AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
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
                          SizedBox(height: 8),
                          Text(
                            'Pull down to refresh',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.all(16),
                  itemCount: _transactions.length + 1, // +1 for header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Header with count
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.history, color: goldColor, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '${_transactions.length} Transaction${_transactions.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Spacer(),
                            Text(
                              'Pull to refresh',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _buildTransactionCard(_transactions[index - 1]);
                  },
                ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final type = tx['type'] ?? 'unknown';
    final amount = tx['amount'] ?? 0;
    final isPositive = amount > 0;
    
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    
    switch (type) {
      case 'topup':
        typeColor = accentGreen;
        typeIcon = Icons.add_circle;
        typeLabel = 'Top Up';
        break;
      case 'purchase':
        typeColor = accentPurple;
        typeIcon = Icons.shopping_bag;
        typeLabel = 'Purchase';
        break;
      case 'refund':
        typeColor = accentBlue;
        typeIcon = Icons.refresh;
        typeLabel = 'Refund';
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help;
        typeLabel = 'Other';
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['description'] ?? typeLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatDateTime(tx['createdAt'] ?? ''),
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}Rp ${_formatNumber(amount.abs())}',
            style: TextStyle(
              color: isPositive ? accentGreen : accentRed,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 📦 DEPOSITS TAB
  // ==========================================

  Widget _buildDepositsTab() {
    if (_deposits.isEmpty && !_isLoadingDeposits) {
      _loadDeposits();
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await _loadDeposits();
        _showInfoSnackbar('Deposits updated');
      },
      color: goldColor,
      backgroundColor: cardDark,
      strokeWidth: 3.0,
      child: _isLoadingDeposits
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: goldColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading deposits...',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            )
          : _deposits.isEmpty
              ? ListView(
                  physics: AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    SizedBox(height: 100),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory, size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text(
                            'No deposit orders',
                            style: TextStyle(color: Colors.white60, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Pull down to refresh',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.all(16),
                  itemCount: _deposits.length + 1, // +1 for header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Header with count and pending indicator
                      final pendingCount = _deposits.where((d) => d['status'] == 'pending').length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2, color: goldColor, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '${_deposits.length} Deposit${_deposits.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (pendingCount > 0) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                ),
                                child: Text(
                                  '$pendingCount pending',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            Spacer(),
                            Text(
                              'Pull to refresh',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _buildDepositCard(_deposits[index - 1]);
                  },
                ),
    );
  }

  Widget _buildDepositCard(Map<String, dynamic> deposit) {
    final status = deposit['status'] ?? 'unknown';
    final Color statusColor;
    
    switch (status) {
      case 'completed':
        statusColor = accentGreen;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.white;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deposit Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      deposit['order_id'] ?? '',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          Divider(color: Colors.white24),
          SizedBox(height: 12),
          
          _buildInfoRow('Amount', 'Rp ${_formatNumber(deposit['amount'] ?? 0)}', goldColor),
          _buildInfoRow('Created', _formatDateTime(deposit['createdAt'] ?? ''), Colors.white60),
          
          if (status == 'pending') ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _currentTopUp = deposit);
                      _showQRISDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('View QRIS'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelDeposit(deposit['order_id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: BorderSide(color: Colors.grey),
                    ),
                    child: Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 🎨 DIALOGS
  // ==========================================

  void _showTopUpDialog() {
    final amounts = [10000, 25000, 50000, 100000, 250000, 500000];
    int? selectedAmount;
    final customController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: goldColor),
              SizedBox(width: 12),
              Text(
                'Top Up Balance',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select amount:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: amounts.map((amount) {
                    final isSelected = selectedAmount == amount;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedAmount = amount;
                          customController.clear();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? goldColor.withOpacity(0.2) : cardDarker,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? goldColor : Colors.white24,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          'Rp ${_formatNumber(amount)}',
                          style: TextStyle(
                            color: isSelected ? goldColor : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
                Text(
                  'Or enter custom amount:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: customController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: cardDarker,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(color: Colors.white),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedAmount = null;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = selectedAmount ?? int.tryParse(customController.text);
                if (amount != null && amount >= 10000) {
                  Navigator.pop(context);
                  _createTopUp(amount);
                } else {
                  _showErrorSnackbar('Minimum top up is Rp 10.000');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: goldColor,
                foregroundColor: Colors.black,
              ),
              child: Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRISDialog() {
    if (_currentTopUp == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.qr_code_2, color: accentBlue),
            SizedBox(width: 12),
            Text(
              'Scan QRIS',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QRIS Image
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.network(
                  _currentTopUp!['qris_url'],
                  width: 250,
                  height: 250,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.error,
                    size: 250,
                    color: Colors.red,
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              Text(
                'Amount to Pay',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                _currentTopUp!['amount_formatted'] ?? '',
                style: TextStyle(
                  color: goldColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              SizedBox(height: 20),
              
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentBlue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: accentBlue, size: 20),
                    SizedBox(height: 8),
                    Text(
                      'Scan the QR code with your e-wallet app',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Payment will be auto-verified',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              
              if (_isVerifyingPayment) ...[
                SizedBox(height: 16),
                CircularProgressIndicator(color: goldColor),
                SizedBox(height: 8),
                Text(
                  'Checking payment...',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopAutoCheckPayment();
              setState(() => _currentTopUp = null);
              Navigator.pop(context);
            },
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _isVerifyingPayment
                ? null
                : () => _verifyTopUp(_currentTopUp!['order_id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              foregroundColor: Colors.white,
            ),
            child: Text('Check Payment'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmDialog(Map<String, dynamic> role) {
    final price = role['price'] ?? 0;
    
    return AlertDialog(
      backgroundColor: cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: goldColor),
          SizedBox(width: 12),
          Text(
            'Confirm Purchase',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are about to purchase:',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardDarker,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role['role_name'] ?? '',
                  style: TextStyle(
                    color: goldColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                _buildInfoRow('Price', 'Rp ${_formatNumber(price)}', Colors.white),
                _buildInfoRow('Duration', '${role['duration_days']} days', Colors.white),
                _buildInfoRow(
                  'New Balance',
                  'Rp ${_formatNumber(_balance - price)}',
                  accentGreen,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: goldColor,
            foregroundColor: Colors.black,
          ),
          child: Text('Confirm'),
        ),
      ],
    );
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: accentGreen, size: 64),
            SizedBox(height: 16),
            Text(
              'Top Up Success!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your balance has been updated',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              '+Rp ${_formatNumber(data['amount'] ?? 0)}',
              style: TextStyle(
                color: accentGreen,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'New Balance: Rp ${_formatNumber(data['new_balance'] ?? 0)}',
              style: TextStyle(color: goldColor, fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGreen,
              foregroundColor: Colors.white,
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

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
        if (index == 1 && _transactions.isEmpty) {
          _loadTransactions();
        } else if (index == 2 && _deposits.isEmpty) {
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
