import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // 🆕 TAMBAHKAN INI

/// 🛒 ROLE SHOP PAGE - Complete Implementation with Group Link Button
/// Sistem pembelian role membership menggunakan QRIS
/// 
/// API Endpoints yang tersedia:
/// ✅ GET  /api/roles                  - Daftar role yang bisa dibeli
/// ✅ POST /api/orders/create          - Buat order & QRIS
/// ✅ POST /api/orders/verify          - Verifikasi pembayaran
/// ✅ POST /api/orders/complete        - Lengkapi order dengan credentials
/// ✅ GET  /api/orders/:order_id       - Detail order
/// ✅ DELETE /api/orders/:order_id     - Cancel order
/// ✅ GET  /api/orders                 - List semua order

class RoleShopPage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final String role;
  final String expiredDate;

  const RoleShopPage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<RoleShopPage> createState() => _RoleShopPageState();
}

class _RoleShopPageState extends State<RoleShopPage> with SingleTickerProviderStateMixin {
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
  
  // Role Catalog
  List<Map<String, dynamic>> _roles = [];
  bool _isLoadingRoles = true;
  
  // Selected Role
  Map<String, dynamic>? _selectedRole;
  
  // Orders
  List<Map<String, dynamic>> _myOrders = [];
  bool _isLoadingOrders = false;
  
  // Current Order (for payment flow)
  Map<String, dynamic>? _currentOrder;
  bool _isCreatingOrder = false;
  bool _isVerifying = false;

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
    _loadRoleCatalog();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🌐 API IMPLEMENTATION
  // ==========================================

  /// ✅ GET /api/roles
  /// Mendapatkan daftar role yang bisa dibeli
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
        debugPrint('✅ Role catalog loaded: ${_roles.length} roles');
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

  /// ✅ POST /api/orders/create
  /// Membuat order dan mendapatkan QRIS
  Future<void> _createOrder(String roleId) async {
    setState(() => _isCreatingOrder = true);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'role_id': roleId,
        }),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _currentOrder = data['data'];
          _isCreatingOrder = false;
        });
        debugPrint('✅ Order created: ${data['data']['order_id']}');
        
        // Show payment dialog
        _showPaymentDialog();
      } else {
        setState(() => _isCreatingOrder = false);
        _showErrorSnackbar(data['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      debugPrint('❌ Error creating order: $e');
      setState(() => _isCreatingOrder = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ POST /api/orders/verify
  /// Verifikasi pembayaran
  Future<void> _verifyPayment(String orderId) async {
    setState(() => _isVerifying = true);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'order_id': orderId,
        }),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() => _isVerifying = false);
        
        if (data['data']['status'] == 'awaiting_credentials') {
          // Payment verified, show credentials form
          _showCredentialsDialog(orderId);
        } else {
          _showInfoSnackbar('Payment not detected yet');
        }
      } else {
        setState(() => _isVerifying = false);
        _showErrorSnackbar(data['message'] ?? 'Payment not verified');
      }
    } catch (e) {
      debugPrint('❌ Error verifying payment: $e');
      setState(() => _isVerifying = false);
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ POST /api/orders/complete
  /// Melengkapi order dengan username dan password
  Future<void> _completeOrder(String orderId, String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'order_id': orderId,
          'username': username,
          'password': password,
        }),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        // Clear current order
        setState(() {
          _currentOrder = null;
        });
        
        // Show success dengan tombol group link
        _showSuccessDialog(data['data']);
      } else {
        _showErrorSnackbar(data['message'] ?? 'Failed to complete order');
      }
    } catch (e) {
      debugPrint('❌ Error completing order: $e');
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ GET /api/orders/:order_id
  /// Mendapatkan detail order
  Future<Map<String, dynamic>?> _getOrderDetail(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderId'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        return data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting order detail: $e');
      return null;
    }
  }

  /// ✅ DELETE /api/orders/:order_id
  /// Cancel order
  Future<void> _cancelOrder(String orderId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/orders/$orderId'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _currentOrder = null;
        });
        _showSuccessSnackbar('Order cancelled');
        Navigator.of(context).pop(); // Close dialog
      } else {
        _showErrorSnackbar(data['message'] ?? 'Failed to cancel order');
      }
    } catch (e) {
      debugPrint('❌ Error cancelling order: $e');
      _showErrorSnackbar('Network error: $e');
    }
  }

  /// ✅ GET /api/orders
  /// List semua orders
  Future<void> _loadAllOrders() async {
    setState(() => _isLoadingOrders = true);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders'),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _myOrders = List<Map<String, dynamic>>.from(data['data']);
          _isLoadingOrders = false;
        });
        debugPrint('✅ Orders loaded: ${_myOrders.length} orders');
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

  // ==========================================
  // 🎨 UI BUILDERS
  // ==========================================

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  /// 🛍️ BUILD BUY TAB - Role Catalog
  Widget _buildBuyTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.shopping_bag, color: goldColor, size: 28),
              SizedBox(width: 12),
              Text(
                'Role Shop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Upgrade role untuk unlock fitur premium',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          
          // Loading
          if (_isLoadingRoles)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: accentBlue),
              ),
            ),
          
          // Role Cards
          if (!_isLoadingRoles)
            ..._roles.map((role) => _buildRoleCard(role)).toList(),
        ],
      ),
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role) {
    final roleType = role['role_type'];
    Color roleColor = accentBlue;
    
    switch (roleType) {
      case 'member':
        roleColor = accentBlue;
        break;
      case 'reseller':
        roleColor = accentPurple;
        break;
      case 'owner':
        roleColor = goldColor;
        break;
    }

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: roleColor, width: 1),
                ),
                child: Text(
                  role['role_name'],
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Spacer(),
              Icon(Icons.star, color: goldColor, size: 20),
            ],
          ),
          SizedBox(height: 12),
          
          // Description
          Text(
            role['description'] ?? '',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          
          // Benefits
          Text(
            'Benefits:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          ...List<String>.from(role['benefits'] ?? []).map((benefit) =>
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: accentGreen, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).toList(),
          
          SizedBox(height: 16),
          Divider(color: Colors.white24),
          SizedBox(height: 16),
          
          // Price & Duration
          Row(
            children: [
              Column(
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
                    role['price_formatted'],
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duration',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    role['duration_days'] == 36500 
                      ? 'Permanent' 
                      : '${role['duration_days']} days',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Buy Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreatingOrder 
                ? null 
                : () => _createOrder(role['role_id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: roleColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isCreatingOrder
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Buy Now',
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
      ),
    );
  }

  // ==========================================
  // 💬 DIALOGS & MODALS
  // ==========================================

  /// 📱 PAYMENT DIALOG - Show QRIS
  void _showPaymentDialog() {
    if (_currentOrder == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.qr_code, color: accentBlue),
            SizedBox(width: 12),
            Text(
              'Payment',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Order Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDarker,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Role', _currentOrder!['role_name'], goldColor),
                    Divider(color: Colors.white24),
                    _buildInfoRow('Price', _currentOrder!['price_formatted'], Colors.white),
                    _buildInfoRow('Admin Fee', 
                      'Rp ${_formatNumber(_currentOrder!['total_payment'] - _currentOrder!['price'])}', 
                      Colors.white60
                    ),
                    Divider(color: Colors.white24),
                    _buildInfoRow('Total', _currentOrder!['total_payment_formatted'], accentGreen),
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // QRIS Code
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.memory(
                  base64Decode(_currentOrder!['qr_code_base64'].split(',').last),
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                ),
              ),
              
              SizedBox(height: 16),
              
              // QRIS String (copyable)
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _currentOrder!['qris_string']));
                  _showSuccessSnackbar('QRIS copied to clipboard');
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardDarker,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentOrder!['qris_string'],
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.copy, color: accentBlue, size: 16),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Instructions
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentBlue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: accentBlue, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Payment Instructions',
                          style: TextStyle(
                            color: accentBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Scan QR code dengan aplikasi e-wallet\n'
                      '2. Lakukan pembayaran\n'
                      '3. Klik "Check Payment" setelah transfer\n'
                      '4. Masukkan username & password',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
            onPressed: () => _cancelOrder(_currentOrder!['order_id']),
            child: Text('Cancel', style: TextStyle(color: accentRed)),
          ),
          ElevatedButton(
            onPressed: _isVerifying 
              ? null 
              : () => _verifyPayment(_currentOrder!['order_id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGreen,
              foregroundColor: Colors.white,
            ),
            child: _isVerifying
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text('Check Payment'),
          ),
        ],
      ),
    );
  }

  /// 🔐 CREDENTIALS DIALOG - After payment verified
  void _showCredentialsDialog(String orderId) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    Navigator.of(context).pop(); // Close payment dialog

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: accentGreen),
            SizedBox(width: 12),
            Text(
              'Payment Verified!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pembayaran berhasil! Silakan buat username dan password untuk akun baru Anda.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 20),
            
            // Username Field
            TextField(
              controller: usernameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: Colors.white60),
                hintText: 'Min. 3 characters',
                hintStyle: TextStyle(color: Colors.white30),
                filled: true,
                fillColor: cardDarker,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.person, color: accentBlue),
              ),
            ),
            SizedBox(height: 12),
            
            // Password Field
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.white60),
                hintText: 'Min. 6 characters',
                hintStyle: TextStyle(color: Colors.white30),
                filled: true,
                fillColor: cardDarker,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.lock, color: accentBlue),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final username = usernameController.text.trim();
              final password = passwordController.text.trim();
              
              if (username.length < 3) {
                _showErrorSnackbar('Username must be at least 3 characters');
                return;
              }
              
              if (password.length < 6) {
                _showErrorSnackbar('Password must be at least 6 characters');
                return;
              }
              
              Navigator.of(context).pop(); // Close dialog
              _completeOrder(orderId, username, password);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Create Account'),
          ),
        ],
      ),
    );
  }

  /// ✅ SUCCESS DIALOG - Order completed WITH GROUP LINK BUTTON
  void _showSuccessDialog(Map<String, dynamic> orderData) {
    final groupLink = orderData['group_update_link'] ?? '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cardDark,
                  cardDarker,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accentGreen.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentGreen.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentGreen,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: accentGreen,
                      size: 50,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    '🎉 Order Berhasil!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'Akun ${orderData['role_name']} sudah aktif',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Account Details Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: goldColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Akun',
                          style: TextStyle(
                            color: goldColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSuccessInfoRow('Username', orderData['username']),
                        _buildSuccessInfoRow('Role', orderData['role_name']),
                        _buildSuccessInfoRow('Expired', orderData['expired_date']),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Benefits List
                  if (orderData['benefits'] != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentBlue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✨ Benefits',
                            style: TextStyle(
                              color: accentBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List<String>.from(orderData['benefits']).map(
                            (benefit) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: accentGreen,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      benefit,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // 🆕 TOMBOL JOIN GROUP (jika ada group link)
                  if (groupLink.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(groupLink);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            _showErrorSnackbar('Tidak bisa membuka link group');
                          }
                        },
                        icon: Icon(Icons.group, size: 20),
                        label: Text(
                          'Join Group Update',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          shadowColor: accentBlue.withOpacity(0.5),
                        ),
                      ),
                    ),
                  
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Reload data
                        _loadAllOrders();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: accentGreen.withOpacity(0.5),
                      ),
                      child: Text(
                        'OK, Mengerti',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 📦 BUILD ORDERS TAB
  Widget _buildOrdersTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: accentBlue, size: 28),
              SizedBox(width: 12),
              Text(
                'My Orders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: _loadAllOrders,
                icon: Icon(Icons.refresh, color: accentBlue),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Riwayat pembelian role',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          
          if (_isLoadingOrders)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: accentBlue),
              ),
            ),
          
          if (!_isLoadingOrders && _myOrders.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.inbox, color: Colors.white30, size: 60),
                    SizedBox(height: 16),
                    Text(
                      'No orders yet',
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          
          if (!_isLoadingOrders && _myOrders.isNotEmpty)
            ..._myOrders.map((order) => _buildOrderCard(order)).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    Color statusColor = _getStatusColor(order['status']);
    
    return _buildGlassCard(
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
                      order['role_name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Order: ${order['order_id']}',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
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
                  order['status'].toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          Divider(color: Colors.white24),
          SizedBox(height: 12),
          
          _buildInfoRow('Amount', order['amount_formatted'], goldColor),
          
          if (order['username'] != null)
            _buildInfoRow('Username', order['username'], accentBlue),
          
          _buildInfoRow('Created', _formatDateTime(order['created_at']), Colors.white60),
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
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return accentGreen;
      case 'pending':
        return Colors.orange;
      case 'awaiting_credentials':
        return accentBlue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.white;
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.shopping_bag,
                  label: 'Shop',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.receipt,
                  label: 'Orders',
                  index: 1,
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
        if (index == 1 && _myOrders.isEmpty) {
          _loadAllOrders();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
      default:
        return _buildBuyTab();
    }
  }
}
