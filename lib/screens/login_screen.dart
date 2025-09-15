import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Standalone login page (if you navigate to /login directly).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in / Sign up')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LoginFormEmbedded(
              onSuccess: () {
                // After login, go back into the app. You can choose where:
                Navigator.pop(context); // closes this page
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Embedded login/sign-up form used by the shell overlay.
/// Calls [onSuccess] when authenticated so parents can dismiss/navigate.
class LoginFormEmbedded extends StatefulWidget {
  const LoginFormEmbedded({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<LoginFormEmbedded> createState() => _LoginFormEmbeddedState();
}

enum _AuthMode { signIn, signUp }

class _LoginFormEmbeddedState extends State<LoginFormEmbedded> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  String? _error;
  bool _acceptTerms = false;

  void _switchMode(_AuthMode m) => setState(() {
    _mode = m;
    _error = null;
  });

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();
      final password = _pass.text;

      if (_mode == _AuthMode.signIn) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        if (!_acceptTerms) {
          throw FirebaseAuthException(
            code: 'terms-not-accepted',
            message: 'Please accept Terms to continue.',
          );
        }
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email sent')),
          );
        }
      }

      if (mounted) widget.onSuccess(); // notify parent (shell or page)
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password reset sent')));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _AuthMode.signUp;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode toggle
          Align(
            alignment: Alignment.centerLeft,
            child: ToggleButtons(
              isSelected: [!isSignUp, isSignUp],
              onPressed: (i) =>
                  _switchMode(i == 0 ? _AuthMode.signIn : _AuthMode.signUp),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Sign In'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Sign Up'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),

          // Password
          TextFormField(
            controller: _pass,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (v) {
              if (v == null || v.length < 6) return 'Min 6 characters';
              return null;
            },
          ),

          if (isSignUp) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass2,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) =>
                  (v != _pass.text) ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _acceptTerms,
              onChanged: (v) => setState(() => _acceptTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I accept the Terms of Service & Privacy Policy',
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _handleSubmit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isSignUp ? 'Create Account' : 'Continue'),
          ),
          if (!isSignUp) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _resetPassword,
              child: const Text('Forgot password?'),
            ),
          ],
        ],
      ),
    );
  }
}
