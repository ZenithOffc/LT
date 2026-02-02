import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages.dart';
import 'tools/bug.dart';
import 'tools/chat.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  late VideoPlayerController _videoController;
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _showSuccessAnimation = false;
  String _successUsername = '';
  double _animationValue = 0.0;
  double _rotationAngle = 0.0;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/banner.mp4')
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
      }).catchError((error) {
        print('Video initialization error: $error');
        setState(() {
          _isVideoInitialized = false;
        });
      });

    _audioPlayer = AudioPlayer();
    _playBackgroundSound();
    _checkAutoLogin();
    _startRotationAnimation();
  }

  Widget _buildGradientCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(25)),
    double borderWidth = 1.5,
    List<BoxShadow>? shadows,
    Color borderColor = const Color(0xFF4A90E2),
    Color? gradientStart,
    Color? gradientEnd,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientStart ?? const Color(0xFF1A2C3D).withOpacity(0.9),
            gradientEnd ?? const Color(0xFF2A4365).withOpacity(0.95),
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor.withOpacity(0.4),
          width: borderWidth,
        ),
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: 3,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  void _startRotationAnimation() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _rotationAngle = 2 * 3.14159;
        });
      }
    });
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('user');
    final savedPassword = prefs.getString('password');
    final savedTime = prefs.getInt('loginTime');
    
    if (savedUser != null && savedPassword != null && savedTime != null) {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final hoursSinceLogin = (currentTime - savedTime) / (1000 * 60 * 60);
      
      if (hoursSinceLogin < 24) {
        setState(() {
          _usernameController.text = savedUser;
          _passwordController.text = savedPassword;
        });
        
        await _loginWithCredentials(savedUser, savedPassword);
      } else {
        await prefs.remove('user');
        await prefs.remove('password');
        await prefs.remove('loginTime');
      }
    }
  }

  Future<void> _loginWithCredentials(String username, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://152.53.187.214:2000/login'),
        headers: {'Content-Type': 'application/json'},
        body: '{"username":"$username","password":"$password"}',
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        final username = _extractValue(responseBody, 'username');
        final role = _extractValue(responseBody, 'role');
        final expired = _extractValue(responseBody, 'expired');
        final status = _extractValue(responseBody, 'status');
        final sender = _extractValue(responseBody, 'sender');

        final userData = {
          'username': username ?? _usernameController.text,
          'role': role ?? 'Premium User',
          'expired': expired ?? 'Never',
          'sender': sender ?? '0',
        };

        if (_isUserExpired(status)) {
          _showExpiredDialog(context);
          return;
        }

        await _saveLoginData(_usernameController.text, _passwordController.text);
        
        setState(() {
          _successUsername = username ?? _usernameController.text;
        });

        _startSuccessAnimation();

        await Future.delayed(const Duration(seconds: 2));

        await _stopBackgroundSound();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainDashboard(user: userData),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Auto login failed. Please login manually.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error during auto login';
        _isLoading = false;
      });
    }
  }

  void _startSuccessAnimation() {
    setState(() {
      _showSuccessAnimation = true;
      _animationValue = 0.0;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _animationValue = 1.0;
        });
      }
    });
  }

  Future<void> _saveLoginData(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', username);
    await prefs.setString('password', password);
    await prefs.setInt('loginTime', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _playBackgroundSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(UrlSource('https://cdn404.savetube.vip/media/8IC3Wu0XGh4/jet-set-speed-up-remix-tiktok-viral-song-128-ytshorts.savetube.me.mp3'));
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _stopBackgroundSound() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      print('Error stopping sound: $e');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both username and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://152.53.187.214:2000/login'),
        headers: {'Content-Type': 'application/json'},
        body: '{"username":"${_usernameController.text}","password":"${_passwordController.text}"}',
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        final username = _extractValue(responseBody, 'username');
        final role = _extractValue(responseBody, 'role');
        final expired = _extractValue(responseBody, 'expired');
        final status = _extractValue(responseBody, 'status');
        final sender = _extractValue(responseBody, 'sender');

        final userData = {
          'username': username ?? _usernameController.text,
          'role': role ?? 'Premium User',
          'expired': expired ?? 'Never',
          'sender': sender ?? '0',
        };

        if (_isUserExpired(status)) {
          _showExpiredDialog(context);
          return;
        }

        await _saveLoginData(_usernameController.text, _passwordController.text);
        
        setState(() {
          _successUsername = username ?? _usernameController.text;
        });

        _startSuccessAnimation();

        await Future.delayed(const Duration(seconds: 2));

        await _stopBackgroundSound();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainDashboard(user: userData),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid username or password';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error';
      });
    } finally {
      if (!_showSuccessAnimation) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isUserExpired(String? status) {
    return status?.toLowerCase() == 'true';
  }

  void _showExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGradientCard(
          padding: const EdgeInsets.all(25),
          borderRadius: const BorderRadius.all(Radius.circular(25)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4A90E2).withOpacity(0.2),
                      const Color(0xFF2A4365).withOpacity(0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.5), width: 2),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFF4A90E2),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ACCOUNT EXPIRED',
                style: TextStyle(
                  color: const Color(0xFF4A90E2).withOpacity(0.9),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Your account subscription has expired.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact developer to renew your subscription.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A4365),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 5,
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _launchTelegram();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 5,
                        shadowColor: const Color(0xFF4A90E2).withOpacity(0.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FontAwesomeIcons.telegram, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'CONTACT',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1,
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
      ),
    );
  }

  Future<void> _launchTelegram() async {
    final url = 'https://t.me/ellsteecu';
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: const Color(0xFF4A90E2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFF4A90E2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      );
    }
  }

  String? _extractValue(String response, String key) {
    try {
      final keyIndex = response.indexOf('"$key"');
      if (keyIndex == -1) return null;
      final valueStart = response.indexOf(':', keyIndex) + 1;
      final valueEnd = response.indexOf(',', valueStart);
      final valueString = response.substring(valueStart, valueEnd == -1 ? response.length : valueEnd);
      return valueString.replaceAll('"', '').trim();
    } catch (e) {
      return null;
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4A90E2),
                          const Color(0xFF2A4365),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4A90E2),
                                  Color(0xFF2A4365),
                                ],
                              ),
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 26),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 15),
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      const Color(0xFF4A90E2),
                      const Color(0xFF2A4365),
                      const Color(0xFF4A90E2),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                child: const Text(
                  'Susanoo',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: Color(0xFF4A90E2),
                        blurRadius: 25,
                      ),
                      Shadow(
                        color: Colors.black,
                        blurRadius: 10,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedRotation(
            turns: _rotationAngle / (2 * 3.14159),
            duration: const Duration(seconds: 20),
            curve: Curves.linear,
            child: Container(
              width: 200,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF4A90E2),
                    const Color(0xFF2A4365),
                    const Color(0xFF4A90E2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBanner() {
    return Container(
      width: double.infinity,
      height: 280,
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildGradientCard(
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            shadows: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 25,
                spreadRadius: 3,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4A90E2).withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isVideoInitialized)
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController.value.size.width,
                          height: _videoController.value.size.height,
                          child: VideoPlayer(_videoController),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1A2C3D),
                            const Color(0xFF2A4365),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4A90E2),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  Container(
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
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            child: _buildGradientCard(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              shadows: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [
                      Color(0xFF4A90E2),
                      Colors.white,
                      Color(0xFF4A90E2),
                    ],
                  ).createShader(bounds);
                },
                child: const Text(
                  'PREMIUM EXPERIENCE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 8,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return _buildGradientCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _usernameController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A2C3D).withOpacity(0.8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF4A90E2).withOpacity(0.4), width: 1.5),
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF4A90E2),
                    size: 18,
                  ),
                ),
                hintText: 'Enter your username',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A2C3D).withOpacity(0.8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF4A90E2).withOpacity(0.4), width: 1.5),
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF4A90E2),
                    size: 18,
                  ),
                ),
                hintText: 'Enter your password',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
          if (_errorMessage.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              child: _buildGradientCard(
                padding: const EdgeInsets.all(10),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderColor: const Color(0xFF4A90E2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4A90E2).withOpacity(0.2),
                            const Color(0xFF4A90E2).withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.4)),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFF4A90E2),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Color(0xFF4A90E2),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 8,
                shadowColor: const Color(0xFF4A90E2).withOpacity(0.4),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.login_rounded, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4A90E2).withOpacity(0.2),
                      const Color(0xFF4A90E2).withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.4)),
                ),
                child: Icon(
                  _isPlaying ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: const Color(0xFF4A90E2),
                  size: 12,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isPlaying ? "JET SET - PLAYING" : 'Sound off',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: AnimatedOpacity(
          opacity: _animationValue,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                transform: Matrix4.translationValues(
                  0,
                  _animationValue * 20,
                  0,
                )..scale(_animationValue),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: const Color(0xFF4A90E2),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF4A90E2),
                                Color(0xFF2A4365),
                              ],
                            ),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 50),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              AnimatedOpacity(
                opacity: _animationValue,
                duration: const Duration(milliseconds: 700),
                child: Transform.translate(
                  offset: Offset(0, _animationValue * 10),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [
                          Color(0xFF4A90E2),
                          Color(0xFF63B3ED),
                          Color(0xFF4A90E2),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 15,
                            offset: Offset(3, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: _animationValue,
                duration: const Duration(milliseconds: 900),
                child: Transform.translate(
                  offset: Offset(0, _animationValue * 8),
                  child: Text(
                    _successUsername.toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        const Shadow(
                          color: Color(0xFF4A90E2),
                          blurRadius: 20,
                          offset: Offset(0, 0),
                        ),
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              AnimatedOpacity(
                opacity: _animationValue,
                duration: const Duration(milliseconds: 1100),
                child: SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.8),
                    ),
                    strokeWidth: 3,
                    backgroundColor: const Color(0xFF4A90E2).withOpacity(0.3),
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
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D1926),
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D1926),
              const Color(0xFF1A2C3D),
              const Color(0xFF2A4365),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            if (_isVideoInitialized)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3,
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      ),
                    ),
                  ),
                ),
              ),
            if (_showSuccessAnimation)
              _buildSuccessAnimation()
            else
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).viewPadding.top + 10,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight - MediaQuery.of(context).viewPadding.vertical - 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          _buildHeader(),
                          _buildVideoBanner(),
                          _buildLoginForm(),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4A90E2).withOpacity(0.1),
                              const Color(0xFF2A4365).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF4A90E2).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '© 2024 Susanoo • PREMIUM ACCESS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF4A90E2).withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
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
    );
  }
}

class MainDashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  const MainDashboard({super.key, required this.user});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentIndex = _pageController.page?.round() ?? 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildGradientCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(25)),
    double borderWidth = 1.5,
    List<BoxShadow>? shadows,
    Color borderColor = const Color(0xFF4A90E2),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2C3D).withOpacity(0.9),
            const Color(0xFF2A4365).withOpacity(0.95),
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor.withOpacity(0.4),
          width: borderWidth,
        ),
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: 3,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    bool isActive = _currentIndex == index;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [
                      Color(0xFF4A90E2),
                      Color(0xFF2A4365),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: isActive
                ? Border.all(color: const Color(0xFF4A90E2).withOpacity(0.5), width: 2)
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1926),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const ClampingScrollPhysics(),
          children: [
            HomePage(user: widget.user),
            AttackPage(user: widget.user),
            CommunityPage(user: widget.user),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: _buildGradientCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          borderRadius: const BorderRadius.all(Radius.circular(25)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
              ),
              _buildNavItem(
                index: 1,
                icon: FontAwesomeIcons.whatsapp,
                activeIcon: FontAwesomeIcons.whatsapp,
                label: 'Attack',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Community',
              ),
            ],
          ),
        ),
      ),
    );
  }
}