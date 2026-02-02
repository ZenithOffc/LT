import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tools/sender.dart';
import 'tools/user.dart';
import 'tools/music.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late VideoPlayerController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/banner.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.setVolume(0.0);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildGradientCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(25)),
    double borderWidth = 1.5,
    List<BoxShadow>? shadows,
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
          color: const Color(0xFF4A90E2).withOpacity(0.4),
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

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: _buildGradientCard(
        padding: const EdgeInsets.all(16),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        borderWidth: isHighlighted ? 2 : 1.5,
        shadows: isHighlighted ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ] : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: color.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isHighlighted)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(8),
          child: _buildGradientCard(
            padding: const EdgeInsets.all(20),
            borderRadius: const BorderRadius.all(Radius.circular(22)),
            shadows: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.25),
                            color.withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      icon,
                      color: color,
                      size: 34,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                if (isPremium) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700).withOpacity(0.2),
                          const Color(0xFFFFA500).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: const Color(0xFFFFD700),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PREMIUM',
                          style: TextStyle(
                            color: const Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeveloperContact() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final url = 'https://t.me/ellsteecu';
          try {
            final Uri uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          } catch (e) {
            print('Error launching URL: $e');
          }
        },
        child: _buildGradientCard(
          padding: const EdgeInsets.all(20),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0088CC).withOpacity(0.25),
                      const Color(0xFF0088CC).withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0088CC).withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0088CC).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  FontAwesomeIcons.telegram,
                  color: Color(0xFF0088CC),
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEVELOPER CONTACT',
                      style: TextStyle(
                        color: const Color(0xFF0088CC).withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Contact @Zenithoffc via Telegram for support and inquiries',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0088CC).withOpacity(0.2),
                      const Color(0xFF0088CC).withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0088CC).withOpacity(0.4)),
                ),
                child: const Icon(
                  Icons.open_in_new_rounded,
                  color: Color(0xFF0088CC),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
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
                width: 44,
                height: 44,
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
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
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
            child: Text(
              'Susanoo',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                shadows: [
                  const Shadow(
                    color: Color(0xFF4A90E2),
                    blurRadius: 25,
                  ),
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBanner() {
    return Container(
      height: 300,
      margin: const EdgeInsets.only(bottom: 35),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildGradientCard(
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.all(Radius.circular(25)),
            shadows: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: const Color(0xFF4A90E2).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_controller.value.isInitialized)
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
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
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4A90E2), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 3,
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
          Positioned(
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4A90E2).withOpacity(0.3),
                    const Color(0xFF2A4365).withOpacity(0.3),
                  ],
                ),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: const Color(0xFF4A90E2),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          const Color(0xFF4A90E2),
                          Colors.white,
                          const Color(0xFF4A90E2),
                        ],
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'PREMIUM EXPERIENCE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [
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
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role']?.toString().toLowerCase() ?? 'user';
    final bool isAdmin = role == 'owner' || role == 'admin' || role == 'reseller';
    
    final List<Widget> featureCards = [
      _buildFeatureCard(
        icon: FontAwesomeIcons.whatsapp,
        title: 'Whatsapp Sender',
        description: 'Manage Sender',
        color: const Color(0xFF25D366),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SenderManagerPage(user: widget.user),
            ),
          );
        },
      ),
      _buildFeatureCard(
        icon: Icons.music_note_rounded,
        title: 'Music Player',
        description: 'Stream YouTube music',
        color: const Color(0xFF2196F3),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MusicPlayerPage(user: widget.user),
            ),
          );
        },
      ),
    ];

    if (isAdmin) {
      featureCards.add(
        _buildFeatureCard(
          icon: Icons.people_alt_rounded,
          title: 'User Manager',
          description: 'Manage users',
          color: const Color(0xFFFF9800),
          isPremium: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserManagerPage(userRole: role),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1926),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1926),
              Color(0xFF1A2C3D),
              Color(0xFF2A4365),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            left: 25,
            right: 25,
            bottom: 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildVideoBanner(),
              _buildGradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4A90E2).withOpacity(0.2),
                                const Color(0xFF2A4365).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: const BorderRadius.all(Radius.circular(15)),
                            border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.4)),
                          ),
                          child: const Icon(
                            Icons.person_pin_rounded,
                            color: Color(0xFF4A90E2),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'USER PROFILE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 5,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            label: 'Username',
                            value: widget.user['username'] ?? 'Unknown',
                            icon: Icons.person_rounded,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                        Expanded(
                          child: _buildInfoCard(
                            label: 'Expiration',
                            value: widget.user['expired'] ?? 'Lifetime',
                            icon: Icons.calendar_month_rounded,
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            label: 'My Role',
                            value: widget.user['role'] ?? 'User',
                            icon: Icons.verified_user_rounded,
                            color: const Color(0xFF2196F3),
                            isHighlighted: isAdmin,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoCard(
                            label: 'My Sender',
                            value: '${widget.user['sender'] ?? '0'} Active',
                            icon: FontAwesomeIcons.whatsapp,
                            color: const Color(0xFF25D366),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              _buildGradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4A90E2).withOpacity(0.2),
                                const Color(0xFF2A4365).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: const BorderRadius.all(Radius.circular(15)),
                            border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.4)),
                          ),
                          child: const Icon(
                            Icons.apps_rounded,
                            color: Color(0xFF4A90E2),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'FEATURES & TOOLS',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 5,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.85,
                      padding: EdgeInsets.zero,
                      children: featureCards,
                    ),
                    const SizedBox(height: 25),
                    _buildDeveloperContact(),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  '© 2024 Susanoo • ALL RIGHTS RESERVED',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}