import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esl_learning_flutter/backend/auth/auth_session_notifier.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

enum AuthView { signin, signup, forgot, reset }

class AuthenticationScreen extends ConsumerStatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  ConsumerState<AuthenticationScreen> createState() =>
      _AuthenticationScreenState();
}

class _AuthenticationScreenState extends ConsumerState<AuthenticationScreen> {
  static const Color _bgGreen = Color(0xFF0F6A3C);
  static const Color _cardGreen = Color(0xFF0D5F38);
  static const Color _iconTileGreen = Color(0xFF1A7D4D);
  static const Color _signInOrange = Color(0xFFB85C2A);
  static const Color _mutedFooter = Color(0xFF8BC4A8);

  String language = 'en';
  AuthView view = AuthView.signin;
  bool _signInBusy = false;
  bool _signUpBusy = false;
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final signupEmailCtrl = TextEditingController();
  final signupPassCtrl = TextEditingController();
  final signupConfirmCtrl = TextEditingController();
  final forgotEmailCtrl = TextEditingController();
  final resetCodeCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  final newPassConfirmCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    signupEmailCtrl.dispose();
    signupPassCtrl.dispose();
    signupConfirmCtrl.dispose();
    forgotEmailCtrl.dispose();
    resetCodeCtrl.dispose();
    newPassCtrl.dispose();
    newPassConfirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGreen,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerRight, child: _langToggle()),
                  const SizedBox(height: 20),
                  Center(child: _appIconTile()),
                  const SizedBox(height: 22),
                  _welcomeBlock(),
                  const SizedBox(height: 10),
                  Text(
                    language == 'en'
                        ? 'Learn Ethiopian Sign Language at your own pace'
                        : 'የኢትዮጵያ የምልክት ቋንቋን በራስዎ ፍጥነት ይማሩ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _pageDots(),
                  const SizedBox(height: 22),
                  if (view == AuthView.signin) _buildSignIn(),
                  if (view == AuthView.signup) _buildSignUp(),
                  if (view == AuthView.forgot) _buildForgot(),
                  if (view == AuthView.reset) _buildReset(),
                ],
              ),
            ),
            if (view == AuthView.signin) _resetDbFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _resetDbFooter(BuildContext context) {
    return Positioned(
      left: 20,
      bottom: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _confirmResetLocalData(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: _mutedFooter.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 6),
                Text(
                  'RESET DB',
                  style: TextStyle(
                    color: _mutedFooter.withValues(alpha: 0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResetLocalData(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset local data?'),
        content: const Text(
          'This clears saved preferences on this device (login state, progress, etc.).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ref.read(authSessionProvider.notifier).signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data cleared. Restart the app.')),
    );
  }

  Widget _langToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_langPill('EN', 'en'), _langPill('አማ', 'am')],
      ),
    );
  }

  Widget _langPill(String text, String value) {
    final selected = language == value;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => language = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? _bgGreen : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _appIconTile() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: _iconTileGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text('👋', style: TextStyle(fontSize: 44)),
    );
  }

  Widget _welcomeBlock() {
    return Column(
      children: [
        Text(
          language == 'en' ? 'Welcome to' : 'እንኳን ደህና መጡ',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'miliketapp',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kAccent,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _pageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(const Color(0xFF0E8F52), 7),
        const SizedBox(width: 10),
        _dot(kAccent, 10, emphasized: true),
        const SizedBox(width: 10),
        _dot(const Color(0xFFE53935), 7),
      ],
    );
  }

  Widget _dot(Color color, double size, {bool emphasized = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _localizeAuthError(String message) {
    if (language == 'en') return message;
    if (message == AuthSessionNotifier.invalidCredentialsMessage) {
      return 'ትክክል ያልሆነ ኢሜይል ወይም የይለፍ ቃል።';
    }
    if (message == AuthSessionNotifier.duplicateEmailMessage) {
      return 'ይህ ኢሜይል ቀድሞውኑ ተመዝግቧል።';
    }
    return message;
  }

  Future<void> _submitSignIn() async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text;

    // Validate email is not empty
    if (email.isEmpty) {
      _showError(
        language == 'en'
            ? 'Please enter your email address'
            : 'እባክዎ ኢሜይል ያስገቡ',
      );
      return;
    }

    // Validate email format
    if (!_isValidEmail(email)) {
      _showError(
        language == 'en'
            ? 'Please enter a valid email address'
            : 'ትክክለኛ ኢሜይል ያስገቡ',
      );
      return;
    }

    // Validate password is not empty
    if (password.isEmpty) {
      _showError(
        language == 'en'
            ? 'Please enter your password'
            : 'እባክዎ የይለፍ ቃልዎን ያስገቡ',
      );
      return;
    }

    // Validate password length
    if (password.length < 6) {
      _showError(
        language == 'en'
            ? 'Password must be at least 6 characters'
            : 'የይለፍ ቃል ቢያንስ 6 ቁምፊ መሆን አለበት',
      );
      return;
    }

    setState(() => _signInBusy = true);
    final err = await ref.read(authSessionProvider.notifier).signIn(email, password);
    if (!mounted) return;
    setState(() => _signInBusy = false);
    if (err != null) {
      _showError(_localizeAuthError(err));
    } else {
      final prefs = await SharedPreferences.getInstance();
      final auth = ref.read(authSessionProvider);
      if (auth.fullName != null) {
        await prefs.setString('userName', auth.fullName!);
      }
      if (auth.email != null) {
        await prefs.setString('userEmail', auth.email!);
      }
    }
  }

  Future<void> _submitSignUp() async {
    final name = nameCtrl.text.trim();
    final email = signupEmailCtrl.text.trim();
    final password = signupPassCtrl.text;
    final confirmPassword = signupConfirmCtrl.text;

    // Validate name is not empty
    if (name.isEmpty) {
      _showError(
        language == 'en'
            ? 'Please enter your full name'
            : 'እባክዎ ሙሉ ስምዎን ያስገቡ',
      );
      return;
    }

    // Validate name length
    if (name.length < 2) {
      _showError(
        language == 'en'
            ? 'Name must be at least 2 characters'
            : 'ስም ቢያንስ 2 ቁምፊ መሆን አለበት',
      );
      return;
    }

    // Validate email is not empty
    if (email.isEmpty) {
      _showError(
        language == 'en'
            ? 'Please enter your email address'
            : 'እባክዎ ኢሜይል ያስገቡ',
      );
      return;
    }

    // Validate email format
    if (!_isValidEmail(email)) {
      _showError(
        language == 'en'
            ? 'Please enter a valid email address'
            : 'ትክክለኛ ኢሜይል ያስገቡ',
      );
      return;
    }

    // Validate password is not empty
    if (password.isEmpty) {
      _showError(
        language == 'en'
            ? 'Please enter a password'
            : 'እባክዎ የይለፍ ቃል ያስገቡ',
      );
      return;
    }

    // Validate password length
    if (password.length < 6) {
      _showError(
        language == 'en'
            ? 'Password must be at least 6 characters'
            : 'የይለፍ ቃል ቢያንስ 6 ቁምፊ መሆን አለበት',
      );
      return;
    }

    // Validate confirm password is not empty
    if (confirmPassword.isEmpty) {
      _showError(
        language == 'en'
            ? 'Please confirm your password'
            : 'እባክዎ የይለፍ ቃልዎን ያረጋግጡ',
      );
      return;
    }

    // Validate passwords match
    if (password != confirmPassword) {
      _showError(
        language == 'en'
            ? 'Passwords do not match'
            : 'የይለፍ ቃሎቹ ምንም አይመሳሰሉም',
      );
      return;
    }

    // All validations passed, proceed with signup
    setState(() => _signUpBusy = true);
    final err = await ref.read(authSessionProvider.notifier).signUp(
          fullName: name,
          email: email,
          password: password,
          languagePreference: language,
        );
    if (!mounted) return;
    setState(() => _signUpBusy = false);
    if (err != null) {
      _showError(_localizeAuthError(err));
    } else {
      final prefs = await SharedPreferences.getInstance();
      final auth = ref.read(authSessionProvider);
      if (auth.fullName != null) {
        await prefs.setString('userName', auth.fullName!);
      }
      if (auth.email != null) {
        await prefs.setString('userEmail', auth.email!);
      }
    }
  }

  Widget _buildSignIn() {
    return _card(
      title: language == 'en' ? 'Sign In' : 'ግባ',
      children: [
        _labeledField(
          label: language == 'en' ? 'Email' : 'ኢሜይል',
          controller: emailCtrl,
          hint: 'your@email.com',
        ),
        const SizedBox(height: 18),
        _labeledField(
          label: language == 'en' ? 'Password' : 'የይለፍ ቃል',
          controller: passCtrl,
          hint: language == 'en' ? 'Enter password' : 'የይለፍ ቃል ያስገቡ',
          obscure: true,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => view = AuthView.forgot),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            child: Text(language == 'en' ? 'Forgot password?' : 'የይለፍ ቃል ረሱ?'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: _signInBusy ? null : _submitSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: _signInOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _signInBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    language == 'en' ? 'Sign In' : 'ግባ',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          language == 'en' ? "Don't have an account?" : 'መለያ የሎዎት?',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () => setState(() => view = AuthView.signup),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              language == 'en' ? 'Sign Up' : 'ይመዝገቡ',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUp() {
    return _card(
      title: language == 'en' ? 'Create Account' : 'መለያ ይፍጠሩ',
      children: [
        _labeledField(
          label: language == 'en' ? 'Full name' : 'ሙሉ ስም',
          controller: nameCtrl,
          hint: language == 'en' ? 'Your name' : 'ስምዎ',
        ),
        const SizedBox(height: 16),
        _labeledField(
          label: language == 'en' ? 'Email' : 'ኢሜይል',
          controller: signupEmailCtrl,
          hint: 'your@email.com',
        ),
        const SizedBox(height: 16),
        _labeledField(
          label: language == 'en' ? 'Password' : 'የይለፍ ቃል',
          controller: signupPassCtrl,
          hint: language == 'en' ? 'Enter password' : 'የይለፍ ቃል',
          obscure: true,
        ),
        const SizedBox(height: 16),
        _labeledField(
          label: language == 'en' ? 'Confirm password' : 'ያረጋግጡ',
          controller: signupConfirmCtrl,
          hint: language == 'en' ? 'Confirm password' : 'የይለፍ ቃል',
          obscure: true,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: _signUpBusy ? null : _submitSignUp,
            style: FilledButton.styleFrom(
              backgroundColor: _signInOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _signUpBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    language == 'en'
                        ? 'Sign Up & Start Learning'
                        : 'ይመዝገቡ & ይጀምሩ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => view = AuthView.signin),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(
              language == 'en' ? 'Back to sign in' : 'ወደ መግቢያ ተመለስ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgot() {
    return _card(
      title: language == 'en' ? 'Forgot Password' : 'የይለፍ ቃል ረሱ',
      children: [
        _labeledField(
          label: language == 'en' ? 'Email' : 'ኢሜይል',
          controller: forgotEmailCtrl,
          hint: 'your@email.com',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: () => setState(() => view = AuthView.reset),
            style: FilledButton.styleFrom(
              backgroundColor: _signInOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              language == 'en' ? 'Send Reset Code' : 'ኮድ ላክ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => view = AuthView.signin),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(language == 'en' ? 'Back to sign in' : 'ወደ መግቢያ ተመለስ'),
          ),
        ),
      ],
    );
  }

  Widget _buildReset() {
    return _card(
      title: language == 'en' ? 'Reset Password' : 'የይለፍ ቃል ዳግም አስጀምር',
      children: [
        _labeledField(
          label: language == 'en' ? 'Reset code' : 'ኮድ',
          controller: resetCodeCtrl,
          hint: language == 'en' ? 'Enter code' : 'ኮድ',
        ),
        const SizedBox(height: 16),
        _labeledField(
          label: language == 'en' ? 'New password' : 'አዲስ የይለፍ ቃል',
          controller: newPassCtrl,
          hint: language == 'en' ? 'Enter password' : 'የይለፍ ቃል',
          obscure: true,
        ),
        const SizedBox(height: 16),
        _labeledField(
          label: language == 'en' ? 'Confirm new password' : 'ያረጋግጡ',
          controller: newPassConfirmCtrl,
          hint: language == 'en' ? 'Confirm password' : 'የይለፍ ቃል',
          obscure: true,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: () => setState(() => view = AuthView.signin),
            style: FilledButton.styleFrom(
              backgroundColor: _signInOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              language == 'en' ? 'Reset Password' : 'ዳግም አስጀምር',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
