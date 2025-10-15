import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/auth/logic/auth_controller.dart';
import 'package:sierra_painting/infra/perf/performance_monitor.dart';
import 'package:sierra_painting/ui/desktop_web_scaffold.dart';
import 'package:sierra_painting/ui/responsive.dart';
import 'package:sierra_painting/ui/ui_keys.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _S();
}

class _S extends ConsumerState<LoginScreen> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+');
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _emailFocus = FocusNode();
  final _pwFocus = FocusNode();
  bool _busy = false;
  TraceHandle? _firstFrame;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _emailFocus.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    () async {
      _firstFrame = await PerformanceMonitor.instance.start(
        'login_screen_first_frame',
      );
    }();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // First stable frame reached
      await _firstFrame?.stop();
    });
  }

  String? _emailV(String? v) {
    if (v == null || v.isEmpty) return 'Email required';
    if (!_emailRe.hasMatch(v)) return 'Please enter a valid email address';
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider);
    try {
      await auth.signIn(email: _email.text.trim(), password: _pw.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      final s = e.toString().toLowerCase();
      final msg = s.contains('user-not-found') || s.contains('wrong-password')
          ? 'Email or password is incorrect'
          : s.contains('network')
          ? 'Network error. Please try again later.'
          : 'Login failed. Please try again.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final bp = bpOf(context);
    final maxW = bp == Breakpoint.desktop
        ? 560.0
        : (bp == Breakpoint.tablet ? 480.0 : 420.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: DesktopWebScaffold(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label: 'Email input field',
                            child: TextFormField(
                              key: UIKeys.email,
                              controller: _email,
                              focusNode: _emailFocus,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: _emailV,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _pwFocus.requestFocus(),
                              autofocus: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            label: 'Password input field',
                            child: TextFormField(
                              key: UIKeys.password,
                              controller: _pw,
                              focusNode: _pwFocus,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              obscureText: true,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Password required'
                                  : null,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            label: 'Log In',
                            hint: 'Submit login form',
                            button: true,
                            enabled: !_busy,
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: UIKeys.signIn,
                                onPressed: _busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Log In'),
                              ),
                            ),
                          ),
                          TextButton(
                            key: UIKeys.forgot,
                            onPressed: () =>
                                Navigator.pushNamed(context, '/forgot'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text('Forgot password?'),
                          ),
                          TextButton(
                            key: UIKeys.create,
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              '/signup',
                            ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text('Create account'),
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
    );
  }
}
