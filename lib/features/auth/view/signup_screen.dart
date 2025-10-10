import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/auth/logic/auth_controller.dart';
import 'package:sierra_painting/ui/desktop_web_scaffold.dart';
import 'package:sierra_painting/ui/responsive.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _S();
}

class _S extends ConsumerState<SignUpScreen> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+');
  static final _passwordRe = RegExp(r'.{8,}');

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  String? _emailV(String? v) {
    if (v == null || v.isEmpty) return 'Email required';
    if (!_emailRe.hasMatch(v)) return 'Please enter a valid email address';
    return null;
  }

  String? _pwV(String? v) {
    if (v == null || !_passwordRe.hasMatch(v)) {
      return 'Your password is too weak. Please choose a stronger password.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider);
    try {
      await auth.signUp(email: _email.text.trim(), password: _pw.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      final txt = e.toString().contains('email-already-in-use')
          ? 'An account with this email already exists'
          : e.toString().toLowerCase().contains('network')
          ? 'Network error. Please try again later.'
          : 'Sign up failed. Please try again.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Create account')),
      body: DesktopWebScaffold(
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
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: _emailV,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pw,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          obscureText: true,
                          validator: _pwV,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
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
                                : const Text('Create Account'),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text('Have an account? Log in'),
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
    );
  }
}
