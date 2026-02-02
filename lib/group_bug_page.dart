import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class GroupBugPage extends StatefulWidget {
  final String username;
  final String password;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;
  final Function(String)? onCoinUpdate;

  const GroupBugPage({
    super.key,
    required this.username,
    required this.password,
    required this.listBug,
    required this.role,
    required this.expiredDate,
    this.onCoinUpdate,
  });

  @override
  State<GroupBugPage> createState() => _GroupBugPageState();
}

class _GroupBugPageState extends State<GroupBugPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final groupLinkController = TextEditingController();
  
  bool _isSending = false;
  String? _responseMessage;
  String _sessionKey = "";
  bool _isLoadingKey = true;
  
  // ✅ UPDATED: Tema warna sesuai DashboardPage
  final Color primaryDark = const Color(0xFF0A0A0A);
  final Color primaryRed = const Color(0xFF8B0000);
  final Color accentRed = const Color(0xFFDC143C);
  final Color lightRed = const Color(0xFFFF6B6B);
  final Color primaryWhite = Colors.white;
  final Color accentGrey = Colors.grey.shade400;
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF141414);
  final Color successGreen = const Color(0xFF10B981);
  
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // ✅ ADDED: Video Player Variables
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // ✅ ADDED: Observer untuk lifecycle
    WidgetsBinding.instance.addObserver(this);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _getSessionKey();
    _initializeVideoPlayer(); // ✅ ADDED
  }

  // ✅ ADDED: Lifecycle handler
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      _reinitializeVideo();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isVideoInitialized) {
        _videoController.pause();
      }
    }
  }

  // ✅ ADDED: Reinitialize video
  void _reinitializeVideo() {
    setState(() {
      _isVideoInitialized = false;
    });

    _chewieController?.dispose();
    _videoController.dispose();

    _initializeVideoPlayer();
  }

  // ✅ ADDED: Initialize video player
  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset(
      'assets/videos/banner.mp4',
    );

    _videoController.initialize().then((_) {
      setState(() {
        _videoController.setVolume(0.1); // Volume 0.1 instead of 0.0
        _videoController.setLooping(true);
        _videoController.play();
        
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: true,
          showControls: false,
          autoInitialize: true,
          aspectRatio: _videoController.value.aspectRatio,
        );
        _isVideoInitialized = true;
      });
    }).catchError((error) {
      print("Video initialization error: $error");
      setState(() {
        _isVideoInitialized = false;
      });
    });
  }

  Future<void> _getSessionKey() async {
    setState(() {
      _isLoadingKey = true;
    });

    try {
      final response = await http.get(
        Uri.parse("https://tapops.fanzhosting.my.id/getKey?username=${widget.username}"),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          setState(() {
            _sessionKey = data['key'];
            _isLoadingKey = false;
          });
        } else {
          _showAlert("⚠️ Error", "Failed to get session key. Please try again.");
          setState(() {
            _isLoadingKey = false;
          });
        }
      } else {
        _showAlert("⚠️ Server Error", "Failed to connect to server.");
        setState(() {
          _isLoadingKey = false;
        });
      }
    } catch (e) {
      print('Error getting session key: $e');
      _showAlert("⚠️ Connection Error", "Check your internet connection.");
      setState(() {
        _isLoadingKey = false;
      });
    }
  }

  @override
  void dispose() {
    // ✅ UPDATED: Remove observer and dispose video controllers
    WidgetsBinding.instance.removeObserver(this);
    groupLinkController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _videoController.dispose(); // ✅ ADDED
    _chewieController?.dispose(); // ✅ ADDED
    super.dispose();
  }

  Future<void> _attackGroup() async {
    if (_isLoadingKey) {
      _showAlert("⏳ Loading", "Please wait while we get your session key.");
      return;
    }

    if (_sessionKey.isEmpty) {
      _showAlert("⚠️ Session Error", "No session key available. Please restart the app.");
      return;
    }

    final groupLink = groupLinkController.text.trim();
    final key = _sessionKey;
    
    if (groupLink.isEmpty || !groupLink.contains('chat.whatsapp.com')) {
      _showAlert("⚠️ Invalid Link", "Please enter a valid WhatsApp group link.");
      return;
    }

    setState(() {
      _isSending = true;
      _responseMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          "https://tapops.fanzhosting.my.id/raidGroup?key=$key&link=$groupLink"
        ),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['valid'] == false) {
          setState(() => _responseMessage = "⚠️ Invalid Key: Please login again.");
          _showAlert("⚠️ Failed", "Invalid session key. Please login again.");
          await _getSessionKey();
          return;
        }
        
        if (data['sended'] == true) {
          if (data["newCoin"] != null && widget.onCoinUpdate != null) {
            widget.onCoinUpdate!(data["newCoin"].toString());
          }

          setState(() {
            _responseMessage = "✅ Successfully sent bug to group!";
          });
          groupLinkController.clear();
          _showAlert("✅ Success", "Successfully sent bug to group!");
        } else {
          setState(() => _responseMessage = "⚠️ Failed to send bug to group.");
          _showAlert("⚠️ Failed", "Failed to send bug to group. Please try again.");
        }
      } else {
        setState(() => _responseMessage = "⚠️ Server error occurred.");
        _showAlert("⚠️ Server Error", "Failed to connect to server. Please try again.");
      }
    } catch (e) {
      print('❌ Group bug error: $e');
      setState(() => _responseMessage = "⚠️ Error: ${e.toString()}");
      _showAlert("⚠️ Error", "An error occurred. Please check your connection and try again.");
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: cardDarker,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: title.startsWith('✅') ? successGreen : accentRed,
            ),
          ),
          content: Text(
            msg,
            style: TextStyle(
              color: accentGrey,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "OK",
                style: TextStyle(
                  color: accentRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                    // Avatar with pulse animation
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
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
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: cardDarker,
                                    child: Icon(
                                      Icons.groups,
                                      size: 32,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Group Raid",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.username,
                            style: const TextStyle(
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
                                              widget.expiredDate,
                                              style: const TextStyle(
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
                                    color: _getRoleBadgeColor(widget.role),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getRoleBorderColor(widget.role),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
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
                                              widget.role.toUpperCase(),
                                              style: const TextStyle(
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
        return const Color(0xFF8B0000);
      case "reseller":
        return const Color(0xFF2E7D32);
      case "premium":
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF424242);
    }
  }

  Color _getRoleBorderColor(String role) {
    switch (role.toLowerCase()) {
      case "owner":
        return const Color(0xFFDC143C);
      case "reseller":
        return const Color(0xFF4CAF50);
      case "premium":
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF757575);
    }
  }

  // ✅ UPDATED: Video thumbnail identical to ContactBugPage
  Widget _buildVideoThumbnail() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 5, bottom: 10, left: 16, right: 16),
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accentRed.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
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
              // Video Player
              if (_isVideoInitialized && _chewieController != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: Chewie(controller: _chewieController!),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryRed.withOpacity(0.4),
                        accentRed.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: accentRed,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              
              // Subtle overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
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

  Widget _buildGroupExecutorCard() {
    return SlideTransition(
      position: _slideAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        Icons.groups,
                        color: accentRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Group Raid Executor",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Group Link Input
                Text(
                  "WhatsApp Group Link",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cardDarker,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentRed.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: groupLinkController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "https://chat.whatsapp.com/...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.link, color: accentRed),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Info card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFFFFD700),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "This tool will join the group, send a bug, and leave without any trace.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
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

  Widget _buildSendButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [primaryRed, accentRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accentRed.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isSending || _isLoadingKey) ? null : _attackGroup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
        ),
        child: (_isSending || _isLoadingKey)
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups, size: 20),
            SizedBox(width: 8),
            Text(
              "ATTACK GROUP",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseMessage() {
    if (_responseMessage == null) return const SizedBox.shrink();

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    if (_responseMessage!.startsWith('✅')) {
      backgroundColor = successGreen.withOpacity(0.2);
      borderColor = successGreen;
      textColor = successGreen;
      icon = Icons.check_circle;
    } else if (_responseMessage!.startsWith('❌') || _responseMessage!.startsWith('⚠️')) {
      backgroundColor = accentRed.withOpacity(0.2);
      borderColor = accentRed;
      textColor = accentRed;
      icon = Icons.error;
    } else {
      backgroundColor = Colors.orange.withOpacity(0.2);
      borderColor = Colors.orange;
      textColor = Colors.orange;
      icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _responseMessage!,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
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
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text(
          'Group Raid',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: cardDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildHeaderSection(),
              _buildVideoThumbnail(),
              _buildGroupExecutorCard(),
              _buildSendButton(),
              _buildResponseMessage(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
