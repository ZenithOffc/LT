import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ContactBugPage extends StatefulWidget {
  final String username;
  final String password;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;
  final Function(String)? onCoinUpdate;
  final String? sessionKey; // ✅ Optional parameter

  const ContactBugPage({
    super.key,
    required this.username,
    required this.password,
    required this.listBug,
    required this.role,
    required this.expiredDate,
    this.sessionKey, // ✅ Optional
    this.onCoinUpdate,
  });

  @override
  State<ContactBugPage> createState() => _ContactBugPageState();
}

class _ContactBugPageState extends State<ContactBugPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final targetController = TextEditingController();
  
  // Map untuk track selected bugs
  Map<String, bool> selectedBugs = {};
  
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
  final Color goldColor = const Color(0xFFFFD700);
  
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Video Player Variables
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // ✅ ADDED: Observer untuk lifecycle
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize selectedBugs map
    for (var bug in widget.listBug) {
      selectedBugs[bug['bug_id']] = false;
    }

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
    
    // ✅ UPDATED: Check if sessionKey is provided, otherwise fetch it
    if (widget.sessionKey != null && widget.sessionKey!.isNotEmpty) {
      _sessionKey = widget.sessionKey!;
      _isLoadingKey = false;
    } else {
      _getSessionKey();
    }
    
    _initializeVideoPlayer();
  }

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

  void _reinitializeVideo() {
    setState(() {
      _isVideoInitialized = false;
    });

    _chewieController?.dispose();
    _videoController.dispose();

    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset(
      'assets/videos/banner.mp4',
    );

    _videoController.initialize().then((_) {
      setState(() {
        _videoController.setVolume(0.1);
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
    WidgetsBinding.instance.removeObserver(this);
    targetController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool get canUseCombo {
    final allowedRoles = ["member", "vip", "reseller", "reseller1", "owner"];
    return allowedRoles.contains(widget.role.toLowerCase());
  }

  List<String> getSelectedBugIds() {
    return selectedBugs.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  Future<void> _sendContactBug() async {
    if (_isLoadingKey) {
      _showAlert("⏳ Loading", "Please wait while we get your session key.");
      return;
    }

    if (_sessionKey.isEmpty) {
      _showAlert("⚠️ Session Error", "No session key available. Please restart the app.");
      return;
    }

    final rawInput = targetController.text.trim();
    final target = formatPhoneNumber(rawInput);
    final key = _sessionKey;

    if (target == null || key.isEmpty) {
      _showAlert("⚠️ Invalid Number",
          "Use international format (e.g., +62, +1, +44), not 08xxx.");
      return;
    }

    final selectedBugIds = getSelectedBugIds();
    
    if (selectedBugIds.isEmpty) {
      _showAlert("⚠️ No Bug Selected", "Please select at least one bug to send.");
      return;
    }

    setState(() {
      _isSending = true;
      _responseMessage = null;
    });

    try {
      String apiUrl;
      
      if (canUseCombo && selectedBugIds.length > 1) {
        final bugsParam = selectedBugIds.join(',');
        apiUrl = "https://tapops.fanzhosting.my.id/sendBugCombo?key=$key&target=$target&bugs=$bugsParam";
      } else {
        final bugId = selectedBugIds.first;
        apiUrl = "https://tapops.fanzhosting.my.id/sendBug?key=$key&target=$target&bug=$bugId";
      }

      final res = await http.get(Uri.parse(apiUrl));
      final data = jsonDecode(res.body);

      if (data["cooldown"] == true) {
        final waitTime = data["wait"] ?? 0;
        setState(() => _responseMessage = "⏳ Cooldown: Wait $waitTime seconds.");
        _showAlert("⏳ Cooldown", "Wait $waitTime seconds before sending another bug.");
      } else if (data["valid"] == false) {
        setState(() => _responseMessage = "⚠️ Invalid Key: Please login again.");
        await _getSessionKey();
      } else if (data["sended"] == false) {
        final reason = data["reason"] ?? "";
        
        // ✅ MODIFIED: Enhanced Role Restricted Alert
        if (reason == "role_restricted") {
          setState(() {
            _isSending = false;
          });
          
          // Get data from API response
          final yourRole = data["yourRole"] ?? widget.role;
          final allowedBugs = data["allowedBugs"];
          final upgradeInfo = data["upgradeInfo"] ?? "Upgrade to unlock more bugs";
          
          // Show custom dialog for role restriction
          _showRoleRestrictedDialog(
            role: yourRole,
            message: data["message"] ?? "This bug is locked for your role.",
            allowedBugs: allowedBugs,
            upgradeInfo: upgradeInfo,
          );
          return;
        }
        
        if (reason == "bug_not_owned") {
          setState(() {
            _isSending = false;
          });
          _showBugNotOwnedDialog(data["message"] ?? "You don't own this bug.");
          return;
        }
        
        if (reason == "coin_not_enough") {
          final currentCoin = data["coin"] ?? 0;
          final required = data["required"] ?? 20;
          setState(() => _responseMessage = "⚠️ Insufficient coins! You have $currentCoin coins, need $required coins.");
          _showAlert("⚠️ Insufficient Coins", "You have $currentCoin coins but need $required coins.");
        } else if (reason == "no_bugs_selected") {
          setState(() => _responseMessage = "⚠️ Select at least 1 bug!");
          _showAlert("⚠️ No Bugs", "Please select at least one bug.");
        } else {
          setState(() => _responseMessage = "⚠️ Failed: ${data["message"] ?? "Server under maintenance."}");
        }
      } else {
        if (data["newCoin"] != null && widget.onCoinUpdate != null) {
          widget.onCoinUpdate!(data["newCoin"].toString());
        }

        final bugsCount = data["bugsCount"] ?? 1;
        setState(() {
          _responseMessage = "✅ Successfully sent $bugsCount bug(s) to $target!";
        });
        targetController.clear();
        
        setState(() {
          for (var key in selectedBugs.keys) {
            selectedBugs[key] = false;
          }
        });
        
        _showAlert("✅ Success", "Successfully sent $bugsCount bug(s) to $target!");
      }
    } catch (e) {
      setState(() => _responseMessage = "⚠️ Error: An error occurred. Try again.");
      _showAlert("⚠️ Error", "An error occurred: $e");
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // ✅ NEW METHOD: Custom dialog for role restriction
  void _showRoleRestrictedDialog({
    required String role,
    required String message,
    dynamic allowedBugs,
    required String upgradeInfo,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: cardDarker,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: accentRed.withOpacity(0.3), width: 1.5),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cardDarker,
                  cardDark,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryRed, accentRed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "🔒 Role Access Required",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentRed.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, color: accentRed, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Your Role: ${role.toUpperCase()}",
                              style: TextStyle(
                                color: accentRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Message
                      Text(
                        message,
                        style: TextStyle(
                          color: primaryWhite.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Allowed Bugs Section
                      if (allowedBugs != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green.shade400,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Your Available Bugs:",
                                    style: TextStyle(
                                      color: Colors.green.shade400,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                allowedBugs == "ALL" 
                                  ? "All bugs are available for your role"
                                  : (allowedBugs is List 
                                      ? allowedBugs.join(", ") 
                                      : allowedBugs.toString()),
                                style: TextStyle(
                                  color: accentGrey,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Upgrade Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              goldColor.withOpacity(0.1),
                              accentRed.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: goldColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: goldColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                upgradeInfo,
                                style: TextStyle(
                                  color: goldColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: cardDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: accentGrey.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: Text(
                            "Close",
                            style: TextStyle(
                              color: accentGrey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryRed, accentRed],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: accentRed.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // TODO: Navigate to upgrade page or shop
                              _showAlert("🌟 Upgrade", "Contact admin to upgrade your account!");
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.upgrade, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  "Upgrade Now",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
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
              color: title.startsWith('✅') ? Colors.green : accentRed,
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

  void _showBugNotOwnedDialog(String message) {
    // Implementation continues as in original file...
    // (Rest of the code remains the same)
  }
  
  // Rest of the methods and widgets remain unchanged...
  // Including: _buildHeaderSection, _buildVideoThumbnail, _buildBugExecutorCard, etc.
}
