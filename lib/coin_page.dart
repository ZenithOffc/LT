import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class CoinPage extends StatefulWidget {
  final String username;
  final String password;
  final String apiBaseUrl;
  final String sessionKey;

  const CoinPage({
    super.key,
    required this.username,
    required this.password,
    required this.apiBaseUrl,
    required this.sessionKey,
  });

  @override
  State<CoinPage> createState() => _CoinPageState();
}

class _CoinPageState extends State<CoinPage> with TickerProviderStateMixin {
  // Theme Colors
  final Color primaryDark = const Color(0xFF000000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF0D0D0D);
  final Color accentRed = const Color(0xFFDC143C);
  final Color accentBlue = const Color(0xFF2196F3);
  final Color goldColor = const Color(0xFFFFD700);
  final Color accentGreen = const Color(0xFF4CAF50);

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _spinController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _spinAnimation;

  // State Variables
  int totalCoin = 0;
  bool isLoading = false;
  bool isSpinning = false;
  bool canSpin = true;
  bool canClaimDaily = true;
  String message = '';
  
  // Spin number animation
  int displayedNumber = 0;
  bool showSpinNumber = false;
  
  final TextEditingController _redeemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _spinController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _spinAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _fetchUserCoin();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _spinController.dispose();
    _redeemController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserCoin() async {
    // Implement API call to get user coin if available
    // For now, we'll set it from spin/claim responses
  }

  Future<void> _animateSpinNumbers(int finalReward) async {
    setState(() {
      showSpinNumber = true;
      displayedNumber = 0;
    });

    // Fast spinning phase (1 second)
    const fastDuration = 50;
    const fastIterations = 20;
    
    for (int i = 0; i < fastIterations; i++) {
      await Future.delayed(const Duration(milliseconds: fastDuration));
      if (mounted) {
        setState(() {
          displayedNumber = math.Random().nextInt(100);
        });
      }
    }

    // Medium speed phase (0.5 second)
    const mediumDuration = 100;
    const mediumIterations = 5;
    
    for (int i = 0; i < mediumIterations; i++) {
      await Future.delayed(const Duration(milliseconds: mediumDuration));
      if (mounted) {
        setState(() {
          displayedNumber = math.Random().nextInt(100);
        });
      }
    }

    // Slow down phase (0.7 second)
    const slowDuration = 150;
    const slowIterations = 4;
    
    for (int i = 0; i < slowIterations; i++) {
      await Future.delayed(const Duration(milliseconds: slowDuration));
      if (mounted) {
        setState(() {
          displayedNumber = math.Random().nextInt(100);
        });
      }
    }

    // Very slow final numbers
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        displayedNumber = math.Random().nextInt(100);
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        displayedNumber = math.Random().nextInt(100);
      });
    }

    // Show final reward
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        displayedNumber = finalReward;
      });
    }

    // Keep showing for a moment then hide
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        showSpinNumber = false;
      });
    }
  }

  Future<void> _spinCoin() async {
    if (isSpinning || !canSpin) return;

    setState(() {
      isSpinning = true;
      message = '';
    });

    _spinController.forward(from: 0.0);

    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/spinCoin?key=${widget.sessionKey}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['valid'] == true) {
          if (data['allowed'] == true) {
            final reward = data['reward'] ?? 0;
            
            await _animateSpinNumbers(reward);
            
            setState(() {
              totalCoin = data['totalCoin'] ?? totalCoin;
              canSpin = false;
              message = reward > 0 
                  ? '🎉 Selamat! Kamu mendapat $reward coin!'
                  : '😢 Zonk! Coba lagi besok!';
            });
            
            if (reward > 0) {
              _showSuccessDialog('Spin Berhasil!', message);
            } else {
              _showErrorDialog('Zonk!', message);
            }
          } else {
            setState(() {
              canSpin = false;
              message = data['message'] ?? 'Spin sudah digunakan hari ini';
            });
            _showErrorDialog('Tidak Bisa Spin', message);
          }
        } else {
          _showErrorDialog('Error', data['message'] ?? 'Invalid key');
        }
      }
    } catch (e) {
      _showErrorDialog('Error', 'Terjadi kesalahan: $e');
    } finally {
      setState(() {
        isSpinning = false;
      });
    }
  }

  Future<void> _claimDaily() async {
    if (isLoading || !canClaimDaily) return;

    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/claimDaily?key=${widget.sessionKey}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['valid'] == true) {
          if (data['success'] == true) {
            final reward = data['reward'] ?? 0;
            setState(() {
              totalCoin = data['totalCoin'] ?? totalCoin;
              canClaimDaily = false;
              message = 'Berhasil claim $reward coin!';
            });
            _showSuccessDialog('Claim Berhasil!', message);
          } else {
            setState(() {
              canClaimDaily = false;
              message = data['message'] ?? 'Sudah claim hari ini';
            });
            _showErrorDialog('Tidak Bisa Claim', message);
          }
        } else {
          _showErrorDialog('Error', data['message'] ?? 'Invalid key');
        }
      }
    } catch (e) {
      _showErrorDialog('Error', 'Terjadi kesalahan: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _redeemCode() async {
    final code = _redeemController.text.trim();
    if (code.isEmpty) {
      _showErrorDialog('Error', 'Masukkan kode redeem');
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/redeemCode'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'key': widget.sessionKey,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['valid'] == true) {
          if (data['success'] == true) {
            final reward = data['reward'] ?? 0;
            setState(() {
              totalCoin = data['totalCoin'] ?? totalCoin;
              _redeemController.clear();
              message = data['message'] ?? 'Redeem berhasil!';
            });
            _showSuccessDialog('Redeem Berhasil!', 'Kamu mendapat $reward coin!');
          } else {
            _showErrorDialog('Redeem Gagal', data['message'] ?? 'Kode tidak valid');
          }
        } else {
          _showErrorDialog('Error', data['message'] ?? 'Invalid key');
        }
      }
    } catch (e) {
      _showErrorDialog('Error', 'Terjadi kesalahan: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        title: title,
        message: message,
        color: accentGreen,
        icon: Icons.check_circle,
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        title: title,
        message: message,
        color: accentRed,
        icon: Icons.error,
      ),
    );
  }

  Widget _buildCustomDialog({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardDark.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 48),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.4), width: 1),
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSpinSection() {
    return _buildGlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.casino,
                  color: accentRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lucky Spin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Spin untuk mendapat coin gratis',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: canSpin && !isSpinning ? _spinCoin : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _spinAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _spinAnimation.value * 2 * math.pi,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: canSpin && !isSpinning
                                ? [accentRed, accentRed.withOpacity(0.6)]
                                : [Colors.grey, Colors.grey.withOpacity(0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: canSpin && !isSpinning
                                  ? accentRed.withOpacity(0.5)
                                  : Colors.transparent,
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.casino,
                          color: Colors.white.withOpacity(showSpinNumber ? 0.3 : 1.0),
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
                if (showSpinNumber)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayedNumber.toString(),
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: goldColor.withOpacity(0.8),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            canSpin
                ? (isSpinning ? 'Spinning...' : 'Tap to Spin!')
                : 'Spin lagi besok!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyClaimSection() {
    return _buildGlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: accentBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Reward',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Claim 80 coin setiap hari',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: canClaimDaily && !isLoading ? _claimDaily : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canClaimDaily && !isLoading
                    ? accentBlue.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: canClaimDaily && !isLoading
                      ? accentBlue.withOpacity(0.4)
                      : Colors.grey.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  canClaimDaily
                      ? (isLoading ? 'Loading...' : 'Claim Daily Reward')
                      : 'Claimed Today',
                  style: TextStyle(
                    color: canClaimDaily && !isLoading
                        ? accentBlue
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection() {
    return _buildGlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.redeem,
                  color: accentGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Redeem Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Masukkan kode untuk mendapat coin',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _redeemController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter redeem code',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: !isLoading ? _redeemCode : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: accentGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentGreen.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  isLoading ? 'Loading...' : 'Redeem',
                  style: TextStyle(
                    color: accentGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Coin Center',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
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
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSpinSection(),
                  const SizedBox(height: 8),
                  _buildDailyClaimSection(),
                  const SizedBox(height: 8),
                  _buildRedeemSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}