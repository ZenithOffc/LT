import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'change_password_page.dart';

class MyInfoPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;

  const MyInfoPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
  });

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  // ===== THEME =====
  final Color bgDark = const Color(0xFF120B0B);
  final Color cardDark = const Color(0xFF1C0F10);
  final Color accentRed = const Color(0xFFDC2626);

  // ===== STATE =====
  File? _profileImage;
  bool showUsername = false;
  bool showPassword = false;
  bool showSessionKey = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
  final XFile? image =
      await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

  if (image != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_${widget.username}', image.path);

    setState(() {
  _profileImage = File(image.path);
  });
  Navigator.pop(context, image.path);
  }
}

Future<void> _loadProfileImage() async {
  final prefs = await SharedPreferences.getInstance();
  final path = prefs.getString('profile_image_${widget.username}');

  if (path != null && File(path).existsSync()) {
    setState(() {
      _profileImage = File(path);
    });
  }
}

  String _mask(String text, {int show = 2}) {
    if (text.length <= show) return "*" * text.length;
    return text.substring(0, show) + "•" * (text.length - show);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Orbitron',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ===== AVATAR =====
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accentRed,
                        accentRed.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Hero(
  tag: 'profile-avatar',
  child: CircleAvatar(
    radius: 55,
    backgroundColor: Colors.transparent,
    backgroundImage:
        _profileImage != null ? FileImage(_profileImage!) : null,
    child: _profileImage == null
        ? const Icon(FontAwesomeIcons.userNinja, size: 42)
        : null,
  ),
),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: accentRed,
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              widget.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              widget.role.toUpperCase(),
              style: TextStyle(
                color: accentRed.withOpacity(0.8),
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 24),

            _infoTile(
              label: "Username",
              value: showUsername
                  ? widget.username
                  : _mask(widget.username),
              toggle: () => setState(() => showUsername = !showUsername),
            ),

            _infoTile(
              label: "Password",
              value: showPassword
                  ? widget.password
                  : "•" * widget.password.length,
              toggle: () => setState(() => showPassword = !showPassword),
            ),

            _staticTile("Role", widget.role.toUpperCase()),
            _staticTile("Expired Date", widget.expiredDate),

            _infoTile(
              label: "Session Key",
              value: showSessionKey
                  ? widget.sessionKey
                  : _mask(widget.sessionKey, show: 6),
              toggle: () => setState(() => showSessionKey = !showSessionKey),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_reset),
                label: const Text(
                  "CHANGE PASSWORD",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangePasswordPage(
                        username: widget.username,
                        sessionKey: widget.sessionKey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
void initState() {
  super.initState();
  _loadProfileImage();
}

  Widget _staticTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accentRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required String label,
    required String value,
    required VoidCallback toggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              value.contains("•")
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: accentRed,
            ),
            onPressed: toggle,
          ),
        ],
      ),
    );
  }
}