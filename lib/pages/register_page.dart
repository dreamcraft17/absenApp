// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../services/auth_service.dart';
// import 'login_page.dart';

// class RegisterPage extends StatefulWidget {
//   const RegisterPage({super.key});

//   @override
//   State<RegisterPage> createState() => _RegisterPageState();
// }

// class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
//   // Palette – match login page
//   final Color _c1 = const Color(0xFF111827); // slate-900
//   final Color _c2 = const Color(0xFF1F2937); // slate-800
//   final Color _primary = const Color(0xFF7C3AED); // violet-600
//   final Color _accent = const Color(0xFF06B6D4);  // cyan-500

//   final _formKey = GlobalKey<FormState>();
//   final _name = TextEditingController();
//   final _email = TextEditingController();
//   final _password = TextEditingController();
//   final _confirm = TextEditingController();
//   final _office = TextEditingController();   // branch
//   final _position = TextEditingController();

//   bool _isLoading = false;
//   bool _obscure1 = true;
//   bool _obscure2 = true;

//   late final AnimationController _ctrl =
//       AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
//   late final Animation<double> _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

//   @override
//   Widget build(BuildContext context) {
//     final auth = Provider.of<AuthService>(context);

//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           tooltip: 'Back',
//           icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           // Gradient background
//           Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [_c1, _c2],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           // Decorative blobs
//           Positioned(top: -70, right: -50, child: _Blob(color: _primary.withOpacity(.35), size: 220)),
//           Positioned(bottom: -60, left: -60, child: _Blob(color: _accent.withOpacity(.28), size: 200)),

//           SafeArea(
//             child: FadeTransition(
//               opacity: _fade,
//               child: Center(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // Title
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: const [
//                           Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 26),
//                           SizedBox(width: 8),
//                           Text(
//                             'Create Account',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.w800,
//                               fontSize: 22,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 18),

//                       // Glass card form
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: BackdropFilter(
//                           filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
//                           child: Container(
//                             padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.08),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(color: Colors.white.withOpacity(0.18)),
//                             ),
//                             child: Form(
//                               key: _formKey,
//                               child: Column(
//                                 children: [
//                                   _GlassField(
//                                     controller: _name,
//                                     label: 'Full Name',
//                                     hint: 'John Doe',
//                                     icon: Icons.person_rounded,
//                                     validator: (v) =>
//                                         (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
//                                   ),
//                                   const SizedBox(height: 12),
//                                   _GlassField(
//                                     controller: _email,
//                                     label: 'Email',
//                                     hint: 'you@company.com',
//                                     keyboardType: TextInputType.emailAddress,
//                                     icon: Icons.alternate_email_rounded,
//                                     validator: (v) {
//                                       if (v == null || v.trim().isEmpty) return 'Email is required';
//                                       final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
//                                       if (!ok) return 'Invalid email address';
//                                       return null;
//                                     },
//                                   ),
//                                   const SizedBox(height: 12),
//                                   _GlassField(
//                                     controller: _password,
//                                     label: 'Password',
//                                     hint: '••••••••',
//                                     icon: Icons.lock_rounded,
//                                     obscure: _obscure1,
//                                     suffix: IconButton(
//                                       onPressed: () => setState(() => _obscure1 = !_obscure1),
//                                       icon: Icon(
//                                         _obscure1 ? Icons.visibility_rounded : Icons.visibility_off_rounded,
//                                         color: Colors.white.withOpacity(.85),
//                                       ),
//                                       tooltip: _obscure1 ? 'Show password' : 'Hide password',
//                                     ),
//                                     validator: (v) {
//                                       if (v == null || v.isEmpty) return 'Password is required';
//                                       if (v.length < 6) return 'At least 6 characters';
//                                       return null;
//                                     },
//                                   ),
//                                   const SizedBox(height: 12),
//                                   _GlassField(
//                                     controller: _confirm,
//                                     label: 'Confirm Password',
//                                     hint: '••••••••',
//                                     icon: Icons.lock_outline_rounded,
//                                     obscure: _obscure2,
//                                     suffix: IconButton(
//                                       onPressed: () => setState(() => _obscure2 = !_obscure2),
//                                       icon: Icon(
//                                         _obscure2 ? Icons.visibility_rounded : Icons.visibility_off_rounded,
//                                         color: Colors.white.withOpacity(.85),
//                                       ),
//                                       tooltip: _obscure2 ? 'Show password' : 'Hide password',
//                                     ),
//                                     validator: (v) {
//                                       if (v == null || v.isEmpty) return 'Please confirm password';
//                                       if (v != _password.text) return 'Password does not match';
//                                       return null;
//                                     },
//                                   ),
//                                   const SizedBox(height: 12),
//                                   _GlassField(
//                                     controller: _office,
//                                     label: 'Office',
//                                     hint: 'Gajah Mada / BSD / Trisakti....',
//                                     icon: Icons.apartment_rounded,
//                                     validator: (v) =>
//                                         (v == null || v.trim().isEmpty) ? 'Office is required' : null,
//                                   ),
//                                   const SizedBox(height: 12),
//                                   _GlassField(
//                                     controller: _position,
//                                     label: 'Position',
//                                     hint: 'IT Staff / Designer',
//                                     icon: Icons.badge_rounded,
//                                     validator: (v) =>
//                                         (v == null || v.trim().isEmpty) ? 'Position is required' : null,
//                                   ),

//                                   const SizedBox(height: 16),

//                                   // Submit
//                                   SizedBox(
//                                     width: double.infinity,
//                                     child: ElevatedButton.icon(
//                                       onPressed: _isLoading
//                                           ? null
//                                           : () async {
//                                               if (!_formKey.currentState!.validate()) return;
//                                               setState(() => _isLoading = true);
//                                               try {
//                                                 final ok = await auth.register(
//                                                   name: _name.text.trim(),
//                                                   email: _email.text.trim(),
//                                                   password: _password.text,
//                                                   branch: _office.text.trim(),
//                                                   position: _position.text.trim(),
//                                                 );
//                                                 if (!mounted) return;
//                                                 if (ok) {
//                                                   ScaffoldMessenger.of(context).showSnackBar(
//                                                     const SnackBar(content: Text('Registered successfully. Please sign in.')),
//                                                   );
//                                                   Navigator.pushReplacement(
//                                                     context,
//                                                     MaterialPageRoute(builder: (_) => const LoginPage()),
//                                                   );
//                                                 } else {
//                                                   ScaffoldMessenger.of(context).showSnackBar(
//                                                     const SnackBar(content: Text('Email is already registered.')),
//                                                   );
//                                                 }
//                                               } catch (e) {
//                                                 if (!mounted) return;
//                                                 ScaffoldMessenger.of(context).showSnackBar(
//                                                   SnackBar(content: Text('Registration error: $e')),
//                                                 );
//                                               } finally {
//                                                 if (!mounted) return;
//                                                 setState(() => _isLoading = false);
//                                               }
//                                             },
//                                       icon: _isLoading
//                                           ? const SizedBox(
//                                               height: 18,
//                                               width: 18,
//                                               child: CircularProgressIndicator(
//                                                 strokeWidth: 2.2,
//                                                 valueColor: AlwaysStoppedAnimation(Colors.white),
//                                               ),
//                                             )
//                                           : const Icon(Icons.check_rounded, color: Colors.white),
//                                       label: const Padding(
//                                         padding: EdgeInsets.symmetric(vertical: 14),
//                                         child: Text('Create Account', style: TextStyle(color: Colors.white)),
//                                       ),
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: _primary,
//                                         foregroundColor: Colors.white,
//                                         disabledBackgroundColor: _primary.withOpacity(.6),
//                                         disabledForegroundColor: Colors.white70,
//                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//                                         textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
//                                       ),
//                                     ),
//                                   ),

//                                   const SizedBox(height: 10),

//                                   // Link to sign in
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Text(
//                                         'Already have an account?',
//                                         style: TextStyle(color: Colors.white.withOpacity(.9)),
//                                       ),
//                                       TextButton(
//                                         onPressed: _isLoading
//                                             ? null
//                                             : () {
//                                                 Navigator.pushReplacement(
//                                                   context,
//                                                   MaterialPageRoute(builder: (_) => const LoginPage()),
//                                                 );
//                                               },
//                                         style: TextButton.styleFrom(
//                                           foregroundColor: Colors.white,
//                                           disabledForegroundColor: Colors.white70,
//                                           overlayColor: Colors.white.withOpacity(.08),
//                                         ),
//                                         child: const Text('Sign in'),
//                                       )
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _name.dispose();
//     _email.dispose();
//     _password.dispose();
//     _confirm.dispose();
//     _office.dispose();
//     _position.dispose();
//     _ctrl.dispose();
//     super.dispose();
//   }
// }

// // ---------- sub widgets ----------
// class _GlassField extends StatelessWidget {
//   final TextEditingController controller;
//   final String label;
//   final String hint;
//   final IconData icon;
//   final bool obscure;
//   final Widget? suffix;
//   final TextInputType? keyboardType;
//   final String? Function(String?)? validator;

//   const _GlassField({
//     required this.controller,
//     required this.label,
//     required this.hint,
//     required this.icon,
//     this.obscure = false,
//     this.suffix,
//     this.keyboardType,
//     this.validator,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(.08),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.white.withOpacity(.18)),
//       ),
//       child: TextFormField(
//         controller: controller,
//         obscureText: obscure,
//         keyboardType: keyboardType,
//         style: const TextStyle(color: Colors.white),
//         validator: validator,
//         decoration: InputDecoration(
//           contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//           labelText: label,
//           labelStyle: TextStyle(color: Colors.white.withOpacity(.9)),
//           hintText: hint,
//           hintStyle: TextStyle(color: Colors.white.withOpacity(.6)),
//           border: InputBorder.none,
//           prefixIcon: Icon(icon, color: Colors.white.withOpacity(.85)),
//           suffixIcon: suffix,
//         ),
//       ),
//     );
//   }
// }

// class _Blob extends StatelessWidget {
//   final double size;
//   final Color color;
//   const _Blob({required this.size, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Transform.rotate(
//       angle: .6,
//       child: Container(
//         width: size,
//         height: size,
//         decoration: BoxDecoration(
//           gradient: RadialGradient(
//             colors: [color, color.withOpacity(0.01)],
//             stops: const [.0, 1],
//           ),
//           borderRadius: BorderRadius.circular(size),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'login_page.dart';

// ===== Palet monokrom (konsisten dgn login) =====
const Color kBlack  = Colors.black;
const Color kB87    = Colors.black87;
const Color kB54    = Colors.black54;
const Color kB12    = Colors.black12;
const Color kGreyBg = Color(0xFFF7F7F7);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _office = TextEditingController();   // branch
  final _position = TextEditingController();

  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  // ====== BRANCH & POSITION DATA ======
  static const String kHeadOffice = 'Gajah Mada Tower ( Head Office)';
  static const List<String> kBranches = [
    kHeadOffice,
    'e+e coffe Kitchen Gajah Mada Plaza',
    'e+e coffe Kitchen UI',
    'e+e coffe Kitchen  Margonda',
    'e+e coffe Kitchen BSD',
    'e+e coffe Kitchen UMN',
    'e+e coffe Kitchen Semanggi',
    'e+e coffe Kitchen MOI',
    'e+e coffe Kitchen Trisakti',
  ];

  static const List<String> kStorePositions = [
    'Chef',
    'Cook',
    'Barista',
    'Waiter / Waitress',
    'Part Time',
  ];

  bool get _isHeadOfficeSelected => _office.text.trim() == kHeadOffice;

  Future<void> _submit(AuthService auth) async {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final ok = await auth.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        branch: _office.text.trim(),
        position: _position.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully. Please sign in.')),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email is already registered.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration error: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Status bar icon gelap
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
    );

    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kBlack),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account', style: TextStyle(color: kBlack, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kB12),
                    boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 8))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Brand header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: kBlack, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.how_to_reg_rounded, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                const Text('e+e Information System',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Let’s get you started',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kBlack),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create your account below',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: kB54),
                            ),

                            const SizedBox(height: 20),

                            // Full name
                            _MonoTextField(
                              controller: _name,
                              label: 'Full Name',
                              hint: 'John Doe',
                              icon: Icons.person_rounded,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                            ),
                            const SizedBox(height: 12),

                            // Email (auto @epluseglobal.com)
                            _MonoTextField(
                              controller: _email,
                              label: 'Email',
                              hint: 'username (auto @epluseglobal.com)',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'Email is required';
                                final ok = RegExp(r'^[^@]+@epluseglobal\.com$').hasMatch(val);
                                if (!ok) return 'Email must end with @epluseglobal.com';
                                return null;
                              },
                              onChanged: (val) {
                                // Selalu pakai domain epluseglobal.com; cursor tetap di sebelum '@'
                                final username = val.split('@').first.trim();
                                final next = username.isEmpty
                                    ? ''
                                    : '$username@epluseglobal.com';
                                if (next != _email.text) {
                                  final caret = username.length;
                                  _email.value = TextEditingValue(
                                    text: next,
                                    selection: TextSelection.collapsed(offset: caret),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // Password
                            _MonoTextField(
                              controller: _password,
                              label: 'Password',
                              hint: '••••••••',
                              icon: Icons.lock_rounded,
                              obscure: _obscure1,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              trailing: IconButton(
                                onPressed: () => setState(() => _obscure1 = !_obscure1),
                                icon: Icon(_obscure1 ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: kB54),
                                tooltip: _obscure1 ? 'Show password' : 'Hide password',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Password is required';
                                if (v.length < 6) return 'At least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Confirm password
                            _MonoTextField(
                              controller: _confirm,
                              label: 'Confirm Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure2,
                              textInputAction: TextInputAction.next,
                              trailing: IconButton(
                                onPressed: () => setState(() => _obscure2 = !_obscure2),
                                icon: Icon(_obscure2 ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: kB54),
                                tooltip: _obscure2 ? 'Show password' : 'Hide password',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Please confirm password';
                                if (v != _password.text) return 'Password does not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Office / Branch (Dropdown)
                            _MonoDropdownField<String>(
                              label: 'Office / Branch',
                              icon: Icons.apartment_rounded,
                              value: _office.text.isEmpty ? null : _office.text,
                              hintText: 'Select branch',
                              items: kBranches
                                  .map((b) => DropdownMenuItem<String>(
                                        value: b,
                                        child: Text(b, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Office is required' : null,
                              onChanged: (v) {
                                setState(() {
                                  _office.text = v ?? '';
                                  // reset position ketika ganti branch
                                  _position.text = '';
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // Position:
                            // - Head Office -> Free text
                            // - Store -> Dropdown (Chef/Cook/Barista/Waiter/Part Time)
                            if (_isHeadOfficeSelected)
                              _MonoTextField(
                                controller: _position,
                                label: 'Position',
                                hint: 'IT Staff / Designer / Finance',
                                icon: Icons.badge_rounded,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.jobTitle],
                                onSubmitted: (_) => _submit(auth),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Position is required' : null,
                              )
                            else
                              _MonoDropdownField<String>(
                                label: 'Position',
                                icon: Icons.badge_rounded,
                                value: _position.text.isEmpty ? null : _position.text,
                                hintText: 'Select position',
                                items: kStorePositions
                                    .map((p) => DropdownMenuItem<String>(
                                          value: p,
                                          child: Text(p),
                                        ))
                                    .toList(),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Position is required' : null,
                                onChanged: (v) => setState(() => _position.text = v ?? ''),
                              ),

                            const SizedBox(height: 16),

                            // Submit
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : () => _submit(auth),
                                icon: _isLoading
                                    ? const SizedBox(
                                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                                    : const Icon(Icons.check_rounded),
                                label: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kBlack,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Link to sign in
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Already have an account?', style: TextStyle(color: kB87)),
                                TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (_) => const LoginPage()),
                                          ),
                                  style: TextButton.styleFrom(foregroundColor: kBlack),
                                  child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _office.dispose();
    _position.dispose();
    _ctrl.dispose();
    super.dispose();
  }
}

// ---------- Sub-widgets util monokrom ----------
class _MonoTextField extends StatelessWidget {
  const _MonoTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.inputFormatters,
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
  final TextCapitalization textCapitalization;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    const baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: kB12),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: kBlack),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: kB54),
        suffixIcon: trailing,
        filled: true,
        fillColor: kGreyBg,
        enabledBorder: baseBorder,
        focusedBorder: baseBorder.copyWith(
          borderSide: const BorderSide(color: kBlack, width: 1.2),
        ),
        errorBorder: baseBorder.copyWith(
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: baseBorder.copyWith(
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class _MonoDropdownField<T> extends StatelessWidget {
  const _MonoDropdownField({
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.value,
    this.hintText,
    this.validator,
  });

  final String label;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final String? hintText;
  final FormFieldValidator<T>? validator;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    const baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: kB12),
    );

    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: kB54),
        filled: true,
        fillColor: kGreyBg,
        enabledBorder: baseBorder,
        focusedBorder: baseBorder.copyWith(
          borderSide: const BorderSide(color: kBlack, width: 1.2),
        ),
        errorBorder: baseBorder.copyWith(
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: baseBorder.copyWith(
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kB54),
      menuMaxHeight: 320,
    );
  }
}
