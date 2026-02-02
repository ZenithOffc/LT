import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'bug_sender.dart';
import 'admin_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'login_page.dart';
import 'anime_home.dart';
import 'spotify.dart';
import 'yts.dart';
import 'tqto.dart';
import 'ai.dart';
import 'info.dart';
import 'shop_page.dart';
import 'coin_page.dart'; // Import CoinPage

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final String coin;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
    required this.coin,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _fadeController;
  late Animation<double> _animation;
  late Animation<double> _fadeAnimation;
  late WebSocketChannel channel;

  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  late String coin;
  late List<Map<String, dynamic>> listBug;
  late List<Map<String, dynamic>> listDoos;
  late List<dynamic> newsList;
  String androidId = "unknown";

  int _selectedTabIndex = 0;
  Widget _selectedPage = const Placeholder();

  int onlineUsers = 0;
  int activeConnections = 0;

  final Color primaryDark = Color(0xFF0A0A0A);
  final Color primaryRed = Color(0xFF8B0000);
  final Color accentRed = Color(0xFFDC143C);
  final Color lightRed = Color(0xFFFF6B6B);
  final Color primaryWhite = Colors.white;
  final Color accentGrey = Colors.grey.shade400;
  final Color cardDark = Color(0xFF1A1A1A);
  final Color cardDarker = Color(0xFF141414);
  final Color redGradientStart = Color(0xFF8B0000);
  final Color redGradientEnd = Color(0xFFDC143C);
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final Color darkRed = Color(0xFF8B0000);
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Channel List
  List<Map<String, dynamic>> channelsList = [
    {
      'name': 'Telegram Channel',
      'description': 'Join our Telegram community for updates',
      'icon': FontAwesomeIcons.telegram,
      'color': Color(0xFF0088cc),
      'url': 'https://t.me/latencylabs',
      'type': 'telegram'
    },
    {
      'name': 'YouTube Channel',
      'description': 'Subscribe for tutorials and content',
      'icon': FontAwesomeIcons.youtube,
      'color': Color(0xFFFF0000),
      'url': 'https://www.youtube.com/@ZenithOfficialId',
      'type': 'youtube'
    },
    {
      'name': 'WhatsApp Channel',
      'description': 'Get instant notifications and support',
      'icon': FontAwesomeIcons.whatsapp,
      'color': Color(0xFF25D366),
      'url': 'https://whatsapp.com/channel/0029Vb7n7eg9RZAfkSEisP0M',
      'type': 'whatsapp'
    },
  ];

  @override
  void initState() {
    super.initState();
    
    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    coin = widget.coin;
    listBug = widget.listBug;
    listDoos = widget.listDoos;
    newsList = widget.news;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _controller.forward();
    _fadeController.forward();

    _selectedPage = _buildNewsPage();

    _initAndroidIdAndConnect();
  }

  // ✅ Method untuk update coin
  void _updateCoin(String newCoin) {
    setState(() {
      coin = newCoin;
    });
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: cardDarker,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text("⚠️ Session Expired",
            style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: accentGrey)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: Text("OK",
                style:
                    TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedTabIndex = index;
      if (index == 0) {
        _selectedPage = _buildNewsPage();
      } else if (index == 1) {
        _selectedPage = HomePage(
          username: username,
          password: password,
          listBug: listBug,
          role: role,
          expiredDate: expiredDate,
          onCoinUpdate: _updateCoin,
        );
      } else if (index == 2) {
        _selectedPage = ShopPage(
          sessionKey: sessionKey,
          username: username,
          password: password,
          role: role,
          expiredDate: expiredDate,
          onCoinUpdate: _updateCoin,
        );
      }
    });
  }

  void _onDrawerItemSelected(int index) {
    setState(() {
      if (index == 4)
        _selectedPage = ChangePasswordPage(
            username: username, sessionKey: sessionKey);
      else if (index == 5)
        _selectedPage = SellerPage(keyToken: sessionKey);
      else if (index == 6) _selectedPage = AdminPage(sessionKey: sessionKey);
    });
  }

  Widget _buildNewsPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderPanel(),
            _buildBannerSection(),
            const SizedBox(height: 20),
            _buildChannelsSection(),
            const SizedBox(height: 20),
            _buildAccountInfo(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPanel() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black.withOpacity(0.3),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Welcome back,",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            username,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Expired Date Card
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Expired",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 9,
                                              ),
                                            ),
                                            Text(
                                              expiredDate,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Role Badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRoleBadgeColor(role),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getRoleBorderColor(role),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shield,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Role",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.8),
                                                fontSize: 9,
                                              ),
                                            ),
                                            Text(
                                              role.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case "owner":
        return Color(0xFF8B0000);
      case "reseller":
        return Color(0xFF2E7D32);
      case "premium":
        return Color(0xFFE65100);
      default:
        return Color(0xFF424242);
    }
  }

  Color _getRoleBorderColor(String role) {
    switch (role.toLowerCase()) {
      case "owner":
        return Color(0xFFDC143C);
      case "reseller":
        return Color(0xFF4CAF50);
      case "premium":
        return Color(0xFFFF9800);
      default:
        return Color(0xFF757575);
    }
  }

  // ✅ Banner section with static image (No Glow Effect)
  Widget _buildBannerSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 5, bottom: 10),
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Static Image Banner
              Image.asset(
                'assets/images/banner.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          darkRed.withOpacity(0.4),
                          accentRed.withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.white.withOpacity(0.5),
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
              
              // Subtle overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.podcasts,
                    color: accentRed,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Connect With Us",
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
        ),
        SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: channelsList.length,
            itemBuilder: (context, index) {
              final channel = channelsList[index];
              return Container(
                width: 240,
                margin: EdgeInsets.only(
                  right: index == channelsList.length - 1 ? 0 : 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      channel['color'].withOpacity(0.7),
                      channel['color'].withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: channel['color'].withOpacity(0.25),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        channel['icon'],
                        size: 90,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  channel['icon'],
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      channel['name'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      channel['description'],
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                final url = channel['url'];
                                if (url != null && url.toString().isNotEmpty) {
                                  launchUrl(
                                    Uri.parse(url),
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: channel['color'],
                                padding: EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 3,
                              ),
                              child: Text(
                                'Join Channel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountInfo() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardDark,
            cardDark,
            Color(0xFF252525),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: accentRed.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Quick Actions",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          // ✅ Sender Manager - Blue Theme (No Glow)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BugSenderPage(
                  sessionKey: sessionKey,
                  username: username,
                  role: role,
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Color(0xFF2196F3).withOpacity(0.15),
                border: Border.all(
                  color: Color(0xFF2196F3).withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(0xFF2196F3).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        FontAwesomeIcons.whatsapp,
                        color: Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Sender Manager",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Add My Sender",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF2196F3).withOpacity(0.8),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardDarker.withOpacity(0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: accentRed,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "More features will be added soon. Stay tuned for updates!",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case "owner":
        return Colors.red;
      case "reseller":
        return Colors.green;
      case "premium":
        return Colors.orange;
      default:
        return lightRed;
    }
  }

  // 🔥 SIDEBAR DENGAN GLASS EFFECT DAN IMAGE HEADER
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.3),
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // 🖼️ IMAGE HEADER (Mengganti bagian merah)
                Container(
                  width: double.infinity,
                  height: 240,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/image/banner.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Icon(
                                  Icons.person,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              username,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accentRed.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Menu Items dengan glass effect background
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _drawerItem(
                        icon: Icons.person,
                        title: "My Info",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyInfoPage(
                                username: username,
                                password: password,
                                role: role,
                                expiredDate: expiredDate,
                                sessionKey: sessionKey,
                              ),
                            ),
                          );
                        },
                      ),
                      _drawerItem(
                        icon: FontAwesomeIcons.coins,
                        title: "Coin Manager",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CoinPage(
                                username: username,
                                password: password,
                                apiBaseUrl: 'https://tapops.fanzhosting.my.id',
                                sessionKey: sessionKey,
                              ),
                            ),
                          );
                        },
                      ),
                      if (role == "reseller" || role == "owner")
                        _drawerItem(
                          icon: Icons.store,
                          title: "Seller Page",
                          onTap: () {
                            Navigator.pop(context);
                            _onDrawerItemSelected(5);
                          },
                        ),
                      if (role == "owner")
                        _drawerItem(
                          icon: Icons.admin_panel_settings,
                          title: "Admin Page",
                          onTap: () {
                            Navigator.pop(context);
                            _onDrawerItemSelected(6);
                          },
                        ),
                      _drawerItem(
                        icon: Icons.movie_filter_outlined,
                        title: "Sub Anime",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => HomeAnimePage()),
                          );
                        },
                      ),
                      _drawerItem(
                        icon: Icons.music_note,
                        title: "YT Music",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => YouTubeS()),
                          );
                        },
                      ),
                      _drawerItem(
                        icon: FontAwesomeIcons.spotify,
                        title: "Spotify",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SpotifyPage()),
                          );
                        },
                      ),
                      _drawerItem(
                        icon: FontAwesomeIcons.robot,
                        title: "AI Assistant",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AIPage(
                                username: username,
                                sessionKey: sessionKey,
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(
                        color: Colors.white.withOpacity(0.1),
                        thickness: 1,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _drawerItem(
                        icon: Icons.logout,
                        title: "Logout",
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          if (!mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => LoginPage()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Menu item dengan hover effect
  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.05),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        hoverColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildDrawerInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: accentRed),
      title: Text(
        label,
        style: TextStyle(color: Colors.white),
      ),
      onTap: onTap,
    );
  }

  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardDarker,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: accentRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Account Information",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            _infoCard(FontAwesomeIcons.user, "Username", username),
            _infoCard(FontAwesomeIcons.calendar, "Expired", expiredDate),
            _infoCard(FontAwesomeIcons.shieldAlt, "Role", role),
            _infoCard(FontAwesomeIcons.coins, "Coins", coin),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.lock_reset, color: Colors.white),
                    label: Text("Change Password"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangePasswordPage(
                            username: username,
                            sessionKey: sessionKey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.logout, color: Colors.white),
                    label: Text("Logout"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => LoginPage()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentRed.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentRed),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(FontAwesomeIcons.coins, color: Color(0xFFFFD700), size: 20),
            SizedBox(width: 8),
            Text(
              coin,
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: primaryDark,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyInfoPage(
                    username: username,
                    password: password,
                    role: role,
                    expiredDate: expiredDate,
                    sessionKey: sessionKey,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: FadeTransition(opacity: _animation, child: _selectedPage),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          bottom: bottomPadding + 16.0,
        ),
        child: Container(
          height: 72.0,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(28.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 25,
                spreadRadius: 3,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28.0),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 15.0,
                    sigmaY: 15.0,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      selectedItemColor: accentRed,
                      unselectedItemColor: Colors.white70,
                      currentIndex: _selectedTabIndex,
                      onTap: _onTabTapped,
                      type: BottomNavigationBarType.fixed,
                      elevation: 0,
                      showSelectedLabels: true,
                      showUnselectedLabels: true,
                      selectedLabelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      selectedFontSize: 13,
                      unselectedFontSize: 12,
                      iconSize: 26.0,
                      items: [
                        BottomNavigationBarItem(
                          icon: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Icon(Icons.home_outlined),
                          ),
                          activeIcon: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Icon(Icons.home),
                          ),
                          label: "Home",
                        ),
                        BottomNavigationBarItem(
                          icon: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Icon(FontAwesomeIcons.whatsapp, size: 22),
                          ),
                          activeIcon: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Icon(FontAwesomeIcons.whatsapp, size: 22),
                          ),
                          label: "WhatsApp",
                        ),
                        BottomNavigationBarItem(
                          icon: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Icon(Icons.shopping_bag_outlined),
                          ),
                          activeIcon: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Icon(Icons.shopping_bag),
                          ),
                          label: "Shop",
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
