import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';
import 'package:esl_learning_flutter/backend/services/localisation_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.language,
    required this.userName,
    required this.userEmail,
    required this.signsLearned,
    required this.streak,
    required this.totalHours,
    required this.onLanguageChanged,
    required this.onProfileSaved,
    required this.onLogout,
  });

  final String language;
  final String userName;
  final String userEmail;
  final int signsLearned;
  final int streak;
  final int totalHours;
  final ValueChanged<String> onLanguageChanged;
  final void Function(String name, String email) onProfileSaved;
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool editMode = false;
  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  final currentPassCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  bool hideCurrentPassword = true;
  bool hideNewPassword = true;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.userName);
    emailCtrl = TextEditingController(text: widget.userEmail);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    currentPassCtrl.dispose();
    newPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      editMode ? _editProfile() : _profileHome();

  Widget _profileHome() {
    return Container(
      color: const Color(0xFFF2F3F2),
      child: Column(
        children: [
          Container(
            height: 74,
            width: double.infinity,
            color: kPrimary,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'Profile'.tr(widget.language),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                _buildProgressCard(),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'Settings'.tr(widget.language),
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildLanguageRow(),
                const SizedBox(height: 12),
                _settingsTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile'.tr(widget.language),
                  subtitle: 'Update your name and password'.tr(widget.language),
                  onTap: () => setState(() => editMode = true),
                ),
                const SizedBox(height: 12),
                _settingsTile(
                  icon: Icons.settings_outlined,
                  title: 'Account Settings'.tr(widget.language),
                  subtitle: 'Manage your account preferences'.tr(widget.language),
                  onTap: () => _showSoonMessage('Account Settings'),
                ),
                const SizedBox(height: 12),
                _logoutTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editProfile() {
    return Container(
      color: const Color(0xFFF7F5F5),
      child: ListView(
        children: [
          Container(
            width: double.infinity,
            color: kPrimary,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => editMode = false),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'Profile'.tr(widget.language),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 136,
                        height: 136,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE4E4E4),
                            width: 2,
                          ),
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child: Container(
                            color: const Color(0xFFF3F3F3),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person,
                              size: 72,
                              color: Color(0xFFBFBFBF),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E7A3D),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Change Profile Picture'.tr(widget.language),
                    style: const TextStyle(
                      color: Color(0xFF0E5A36),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Full Name'.tr(widget.language),
                  style: const TextStyle(
                    color: Color(0xFF272727),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _inputBox(controller: nameCtrl, hint: 'Your name'.tr(widget.language)),
                const SizedBox(height: 20),
                Text(
                  'Email Address'.tr(widget.language),
                  style: const TextStyle(
                    color: Color(0xFF272727),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _inputBox(controller: emailCtrl, hint: 'user@example.com'),
                const SizedBox(height: 26),
                Text(
                  'SECURITY'.tr(widget.language),
                  style: const TextStyle(
                    color: Color(0xFF636363),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Current Password'.tr(widget.language),
                  style: const TextStyle(
                    color: Color(0xFF272727),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _inputBox(
                  controller: currentPassCtrl,
                  hint: '',
                  obscure: hideCurrentPassword,
                  suffix: IconButton(
                    onPressed: () => setState(
                      () => hideCurrentPassword = !hideCurrentPassword,
                    ),
                    icon: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: Color(0xFF878787),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'New Password'.tr(widget.language),
                  style: const TextStyle(
                    color: Color(0xFF272727),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _inputBox(
                  controller: newPassCtrl,
                  hint: '',
                  obscure: hideNewPassword,
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => hideNewPassword = !hideNewPassword),
                    icon: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: Color(0xFF878787),
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    onPressed: () {
                      widget.onProfileSaved(nameCtrl.text, emailCtrl.text);
                      setState(() => editMode = false);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF045E30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Changes'.tr(widget.language),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
  }

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF858585),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF1EFEF),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13743E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC4A300),
                    width: 2.3,
                  ),
                  color: const Color(0xFFF4F4F4),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF93A39C),
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.userName} 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track your progress'.tr(widget.language),
                      style: const TextStyle(
                        color: Color(0xFFD2E4D8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  value: widget.signsLearned,
                  label: 'SIGNS\nLEARNED'.tr(widget.language),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  value: widget.streak,
                  label: 'DAY STREAK'.tr(widget.language),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  value: widget.totalHours,
                  label: 'PRACTICED'.tr(widget.language),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard({required int value, required String label}) {
    return Container(
      height: 106,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFFEAC326),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE2E9E5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8F4EC),
            ),
            child: const Icon(Icons.language, color: Color(0xFF238A52)),
          ),
          const SizedBox(width: 12),
          Text(
            'Language'.tr(widget.language),
            style: const TextStyle(
              color: Color(0xFF1C1C1C),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE2E2E2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _languagePill(
                      label: 'English'.tr(widget.language),
                      active: widget.language == 'en',
                      onTap: () => widget.onLanguageChanged('en'),
                    ),
                  ),
                  Expanded(
                    child: _languagePill(
                      label: 'Amharic'.tr(widget.language),
                      active: widget.language == 'am',
                      onTap: () => widget.onLanguageChanged('am'),
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

  Widget _languagePill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF177C45) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF6C7275),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8F4EC),
                ),
                child: Icon(icon, color: const Color(0xFF1E9757)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6E7578),
                        fontSize: 14 / 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF7C7C7C),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoutTile() {
    return Material(
      color: const Color(0xFFF9EEEF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEEDDE0)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFF5DFE3),
                child: Icon(Icons.logout, color: Color(0xFFBE2C3C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Log Out'.tr(widget.language),
                  style: const TextStyle(
                    color: Color(0xFFB91F32),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFC26772)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSoonMessage(String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${title.tr(widget.language)} ${'coming soon'.tr(widget.language)}')));
  }
}
