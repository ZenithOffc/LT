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
        
        if (reason == "role_restricted") {
          setState(() {
            _isSending = false;
          });
          _showAlert("⚠️ Role Restricted", data["message"] ?? "This feature is not available for your role.");
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
    final selectedBugIds = getSelectedBugIds();
    final firstBugId = selectedBugIds.isNotEmpty ? selectedBugIds.first : '';
    
    final selectedBug = widget.listBug.firstWhere(
      (bug) => bug['bug_id'] == firstBugId,
      orElse: () => {'bug_name': 'Unknown Bug'},
    );
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: cardDarker,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: accentRed.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accentRed.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentRed.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: accentRed,
                  size: 50,
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                "Bug Locked",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentRed.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  selectedBug['bug_name'] ?? 'Unknown',
                  style: TextStyle(
                    color: accentRed,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 8),
              
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
                      color: goldColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Purchase this bug from the shop to unlock it",
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
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Close",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayloadSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: accentRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: goldColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            color: goldColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Select Payloads",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                canUseCombo 
                                  ? "Tap to select bugs for combo attack"
                                  : "Select one bug to send (freemember)",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.role.toLowerCase() == "owner")
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: goldColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: goldColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              "OWNER MODE",
                              style: TextStyle(
                                color: goldColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setModalState) {
                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: widget.listBug.length,
                          itemBuilder: (context, index) {
                            final bug = widget.listBug[index];
                            final bugId = bug['bug_id'];
                            final isSelected = selectedBugs[bugId] ?? false;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (canUseCombo) {
                                    selectedBugs[bugId] = !isSelected;
                                  } else {
                                    for (var key in selectedBugs.keys) {
                                      selectedBugs[key] = false;
                                    }
                                    selectedBugs[bugId] = true;
                                  }
                                });
                                setModalState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                    ? goldColor.withOpacity(0.1)
                                    : Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected 
                                      ? goldColor.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.1),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: goldColor.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ] : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected 
                                          ? goldColor
                                          : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected 
                                            ? goldColor
                                            : Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.black,
                                            size: 16,
                                          )
                                        : null,
                                    ),
                                    
                                    const SizedBox(width: 12),
                                    
                                    Expanded(
                                      child: Text(
                                        bug['bug_name'] ?? 'Unknown',
                                        style: TextStyle(
                                          color: isSelected 
                                            ? Colors.white 
                                            : Colors.white.withOpacity(0.8),
                                          fontWeight: isSelected 
                                            ? FontWeight.bold 
                                            : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: isSelected,
                                        onChanged: (value) {
                                          setState(() {
                                            if (canUseCombo) {
                                              selectedBugs[bugId] = value;
                                            } else {
                                              for (var key in selectedBugs.keys) {
                                                selectedBugs[key] = false;
                                              }
                                              selectedBugs[bugId] = value;
                                            }
                                          });
                                          setModalState(() {});
                                        },
                                        activeColor: goldColor,
                                        activeTrackColor: goldColor.withOpacity(0.5),
                                        inactiveThumbColor: Colors.white.withOpacity(0.3),
                                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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
                                      Icons.person,
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
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Bug Executor",
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

  Widget _buildBugExecutorCard() {
    final selectedCount = selectedBugs.values.where((v) => v == true).length;
    final selectedBugIds = getSelectedBugIds();
    
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
                        Icons.bug_report,
                        color: accentRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Bug Executor",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  "Target Number",
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
                    controller: targetController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "e.g. +62xxxxxxxxxx",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.phone_android, color: accentRed),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  "Select Bug",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showPayloadSelectionDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardDarker,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedCount > 0 
                          ? accentRed.withOpacity(0.5)
                          : accentRed.withOpacity(0.3),
                      ),
                      boxShadow: selectedCount > 0 ? [
                        BoxShadow(
                          color: accentRed.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedCount == 0 
                              ? "Tap to select bug(s)"
                              : selectedBugIds.map((id) {
                                  final bug = widget.listBug.firstWhere(
                                    (b) => b['bug_id'] == id,
                                    orElse: () => {'bug_name': id},
                                  );
                                  return bug['bug_name'];
                                }).join(", "),
                            style: TextStyle(
                              color: selectedCount > 0 
                                ? Colors.white 
                                : Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: selectedCount > 0 
                                ? FontWeight.w500 
                                : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: accentRed,
                          size: 24,
                        ),
                      ],
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
        onPressed: (_isSending || _isLoadingKey) ? null : _sendContactBug,
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
            Icon(Icons.send, size: 20),
            SizedBox(width: 8),
            Text(
              "SEND BUG",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text(
          'Contact Bug',
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
              _buildBugExecutorCard(),
              _buildSendButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
