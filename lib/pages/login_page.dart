import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'home_page.dart';
import 'register_page.dart';

const Color kPrimary = Color(0xFF6366F1);
const Color kSecondary = Color(0xFFA855F7);
const Color kAccent = Color(0xFFEC4899);
const Color kWhite = Colors.white;
const Color kBlack = Colors.black;
const Color kGlass = Color(0x1AFFFFFF);
const Color kGlassBorder = Color(0x33FFFFFF);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pass = TextEditingController();

  bool _isLoading = false;
  bool _isTesting = false;
  bool _obscure = true;
  bool _navigated = false;
  int? _lastLatencyMs;

  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  late final Animation<double> _fadeAll =
      CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slideCard =
      Tween(begin: const Offset(0, .08), end: Offset.zero).animate(
        CurvedAnimation(parent: _enter, curve: const Interval(.2, 1, curve: Curves.easeOutCubic)),
      );
  late final Animation<double> _scaleCard =
      Tween(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _enter, curve: const Interval(.2, 1, curve: Curves.easeOutCubic)),
      );

  Future<void> _runTestConnection() async {
    if (_isTesting) return;
    setState(() => _isTesting = true);
    try {
      final result = await ApiService.testConnection();
      if (!mounted) return;
      if (result['success'] == true) {
        _lastLatencyMs = (result['latency_ms'] as int?) ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Text('Connected • ${_lastLatencyMs} ms (HTTP ${result['status']})',
                style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Text('Connection failed: ${result['error'] ?? result['message'] ?? 'Unknown error'}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text('Test error: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isTesting = false);
    }
  }

  Future<void> _submit(AuthService auth) async {
    if (_isLoading) return;
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final ok = await auth.login(_name.text.trim(), _pass.text);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: const Text('Signed in successfully', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: const Text('Login failed. Check your credentials.', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text('Login error: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: kPrimary,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    if (auth.isLoggedIn && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      });
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kPrimary, kSecondary, kAccent],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAll,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1000;

                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: wide ? _WideLayout(auth) : _MobileLayout(auth),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _WideLayout(AuthService auth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: _EditorialHeader()),
        const SizedBox(width: 64),
        ScaleTransition(
          scale: _scaleCard,
          child: SlideTransition(
            position: _slideCard,
            child: _GlassCard(child: _LoginCard()),
          ),
        ),
      ],
    );
  }

  Widget _MobileLayout(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBrand(),
        const SizedBox(height: 24),
        _EditorialHeader(isCompact: true),
        const SizedBox(height: 24),
        Expanded(
          child: ScaleTransition(
            scale: _scaleCard,
            child: SlideTransition(
              position: _slideCard,
              child: _GlassCard(child: _LoginCard()),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _pass.dispose();
    _enter.dispose();
    super.dispose();
  }
}

// =================== Subwidgets ===================

class _TopBrand extends StatelessWidget {
  const _TopBrand({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kWhite, Color(0xFFE0E7FF)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kBlack.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.local_cafe_rounded, color: kPrimary, size: 28),
        ),
        const SizedBox(width: 12),
        const Text(
          'E+E Coffee',
          style: TextStyle(
            color: kWhite,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _EditorialHeader extends StatelessWidget {
  final bool isCompact;
  const _EditorialHeader({this.isCompact = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kGlass,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: kGlassBorder, width: 1.5),
          ),
          child: const Text(
            'WELCOME BACK',
            style: TextStyle(
              color: kWhite,
              letterSpacing: 3,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isCompact ? 'Hello again.\n Wellcome!' : 'Hello again.\n Wellcome!.',
          textAlign: isCompact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: kWhite,
            fontSize: isCompact ? 38 : 56,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            shadows: [
              Shadow(
                color: kBlack.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sign in to access your employee dashboard',
          textAlign: isCompact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: kWhite.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: kWhite.withOpacity(0.15),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: kWhite.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: kBlack.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(32),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({super.key});
  @override
  Widget build(BuildContext context) {
    final _state = context.findAncestorStateOfType<_LoginPageState>()!;
    return _LoginForm(
      formKey: _state._formKey,
      name: _state._name,
      pass: _state._pass,
      isLoading: _state._isLoading,
      isTesting: _state._isTesting,
      lastLatencyMs: _state._lastLatencyMs,
      obscure: _state._obscure,
      onToggleObscure: () => _state.setState(() => _state._obscure = !_state._obscure),
      onSubmit: () => _state._submit(Provider.of<AuthService>(context, listen: false)),
      onTestConnection: _state._runTestConnection,
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required GlobalKey<FormState> formKey,
    required TextEditingController name,
    required TextEditingController pass,
    required bool isLoading,
    required bool isTesting,
    required int? lastLatencyMs,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required VoidCallback onSubmit,
    required VoidCallback onTestConnection,
    Key? key,
  })  : _formKey = formKey,
        _name = name,
        _pass = pass,
        _isLoading = isLoading,
        _isTesting = isTesting,
        _lastLatencyMs = lastLatencyMs,
        _obscure = obscure,
        _onToggleObscure = onToggleObscure,
        _onSubmit = onSubmit,
        _onTestConnection = onTestConnection,
        super(key: key);

  final GlobalKey<FormState> _formKey;
  final TextEditingController _name;
  final TextEditingController _pass;
  final bool _isLoading;
  final bool _isTesting;
  final int? _lastLatencyMs;
  final bool _obscure;
  final VoidCallback _onToggleObscure;
  final VoidCallback _onSubmit;
  final VoidCallback _onTestConnection;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kWhite, Color(0xFFE0E7FF)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_cafe_rounded, color: kPrimary, size: 32),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Portal',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: kWhite,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xCCFFFFFF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          _GlassField(
            controller: _name,
            label: 'Username',
            hint: 'e.g. john_doe',
            icon: Icons.person_rounded,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            autofillHints: const [AutofillHints.username],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Username is required';
              if (v.trim().length < 3) return 'At least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _GlassField(
            controller: _pass,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_rounded,
            obscure: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _isLoading ? null : _onSubmit(),
            trailing: IconButton(
              onPressed: _onToggleObscure,
              icon: Icon(
                _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: kWhite.withOpacity(0.7),
              ),
              tooltip: _obscure ? 'Show password' : 'Hide password',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            },
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : () {},
              style: TextButton.styleFrom(
                foregroundColor: kWhite,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kWhite, Color(0xFFE0E7FF)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kWhite.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: kPrimary,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.8, color: kPrimary),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account?",
                style: TextStyle(color: kWhite.withOpacity(0.8), fontWeight: FontWeight.w500),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        ),
                style: TextButton.styleFrom(foregroundColor: kWhite),
                child: const Text(
                  'Create one',
                  style: TextStyle(fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),

          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  kWhite.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Container(
            height: 52,
            decoration: BoxDecoration(
              color: kWhite.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kWhite.withOpacity(0.2), width: 1.5),
            ),
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _onTestConnection,
              style: OutlinedButton.styleFrom(
                foregroundColor: kWhite,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _isTesting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: kWhite),
                    )
                  : const Icon(Icons.network_check_rounded, size: 22),
              label: Text(
                _isTesting
                    ? 'Testing...'
                    : (_lastLatencyMs != null ? 'Connected (${_lastLatencyMs}ms)' : 'Test Connection'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            '© 2025 EplusE • E&E Coffee',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kWhite.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.textInputAction,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: kWhite.withOpacity(0.3), width: 1.5),
    );
    final focus = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kWhite, width: 2),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: kWhite.withOpacity(0.1),
        labelStyle: TextStyle(color: kWhite.withOpacity(0.8), fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: kWhite.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: kWhite.withOpacity(0.7), size: 22),
        suffixIcon: trailing,
        enabledBorder: base,
        focusedBorder: focus,
        errorBorder: base.copyWith(borderSide: const BorderSide(color: kAccent, width: 1.5)),
        focusedErrorBorder: focus.copyWith(borderSide: const BorderSide(color: kAccent, width: 2)),
        errorStyle: const TextStyle(color: kAccent, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}