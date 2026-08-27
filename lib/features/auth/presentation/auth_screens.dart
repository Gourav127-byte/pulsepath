import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import 'email_auth_sheet.dart';
import 'phone_auth_sheet.dart';

enum _AuthPage { login, signUp, forgot, reset }

class AuthFlow extends ConsumerStatefulWidget {
  const AuthFlow({super.key});

  @override
  ConsumerState<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends ConsumerState<AuthFlow> {
  _AuthPage _page = _AuthPage.login;
  String? _developmentResetToken;

  void _show(_AuthPage page, {String? developmentResetToken}) {
    ref.read(authControllerProvider.notifier).clearError();
    setState(() {
      _page = page;
      _developmentResetToken = developmentResetToken;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_page) {
      _AuthPage.login => LoginScreen(
        onSignUp: () => _show(_AuthPage.signUp),
        onForgotPassword: () => _show(_AuthPage.forgot),
      ),
      _AuthPage.signUp => SignUpScreen(onLogin: () => _show(_AuthPage.login)),
      _AuthPage.forgot => ForgotPasswordScreen(
        onBack: () => _show(_AuthPage.login),
        onSubmitted: (token) =>
            _show(_AuthPage.reset, developmentResetToken: token),
      ),
      _AuthPage.reset => ResetPasswordScreen(
        initialToken: _developmentResetToken,
        onBack: () => _show(_AuthPage.login),
        onComplete: () => _show(_AuthPage.login),
      ),
    };
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    required this.onSignUp,
    required this.onForgotPassword,
    super.key,
  });

  final VoidCallback onSignUp;
  final VoidCallback onForgotPassword;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth.status == AuthStatus.loading;
    return _AuthScaffold(
      eyebrow: 'WELCOME BACK',
      title: 'Keep moving forward.',
      subtitle: 'Sign in to continue your PulsePath journey.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EmailField(controller: _email),
            const SizedBox(height: 14),
            _PasswordField(
              key: const Key('login_password'),
              controller: _password,
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: loading ? null : widget.onForgotPassword,
                child: const Text('Forgot Password?'),
              ),
            ),
            if (auth.message != null) _ErrorText(auth.message!),
            const SizedBox(height: 6),
            FilledButton(
              key: const Key('login_button'),
              onPressed: loading ? null : _submit,
              child: loading ? const _ButtonProgress() : const Text('Login'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: PulsePathColors.textSecondary.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('google_signin_button'),
              onPressed: loading ? null : _googleSignIn,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Sign in with Google'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('phone_auth_button'),
              onPressed: loading ? null : _openPhoneAuth,
              icon: const Icon(Icons.phone_android_rounded, size: 20),
              label: const Text('Sign in with Phone Number'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('email_otp_auth_button'),
              onPressed: loading ? null : _openEmailAuth,
              icon: const Icon(Icons.mark_email_unread_rounded, size: 20),
              label: const Text('Sign in with Email OTP'),
            ),
            const SizedBox(height: 16),
            _AuthLink(
              prompt: 'New to PulsePath?',
              action: 'Create account',
              onPressed: loading ? null : widget.onSignUp,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _googleSignIn() async {
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .signInWithGoogleNative();
      ref.read(authControllerProvider.notifier).setSession(session);
    } on AuthException catch (e) {
      if (mounted && !e.message.contains('cancelled')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e')),
        );
      }
    }
  }

  void _openPhoneAuth() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulsePathColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PhoneAuthSheet(),
    );
  }

  void _openEmailAuth() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulsePathColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const EmailAuthSheet(),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({required this.onLogin, super.key});
  final VoidCallback onLogin;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .register(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth.status == AuthStatus.loading;
    return _AuthScaffold(
      eyebrow: 'START YOUR PATH',
      title: 'Build something better.',
      subtitle: 'Create your PulsePath account in a few seconds.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EmailField(controller: _email),
            const SizedBox(height: 14),
            _PasswordField(
              key: const Key('signup_password'),
              controller: _password,
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
              validateLength: true,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('confirm_password'),
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (value) =>
                  value != _password.text ? 'Passwords do not match.' : null,
            ),
            if (auth.message != null) ...[
              const SizedBox(height: 12),
              _ErrorText(auth.message!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('signup_button'),
              onPressed: loading ? null : _submit,
              child: loading
                  ? const _ButtonProgress()
                  : const Text('Create account'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: PulsePathColors.textSecondary.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('google_signup_button'),
              onPressed: loading ? null : _googleSignUp,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Sign up with Google'),
            ),
            const SizedBox(height: 16),
            _AuthLink(
              prompt: 'Already have an account?',
              action: 'Login',
              onPressed: widget.onLogin,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _googleSignUp() async {
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .signInWithGoogleNative();
      ref.read(authControllerProvider.notifier).setSession(session);
    } on AuthException catch (e) {
      if (mounted && !e.message.contains('cancelled')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-Up failed: $e')),
        );
      }
    }
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    required this.onBack,
    required this.onSubmitted,
    super.key,
  });
  final VoidCallback onBack;
  final ValueChanged<String?> onSubmitted;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _successMessage;
  String? _developmentToken;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .forgotPassword(_email.text);
      if (mounted) {
        setState(() {
          _successMessage = result.message;
          _developmentToken = result.developmentToken;
        });
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      eyebrow: 'PASSWORD RECOVERY',
      title: 'Find your way back.',
      subtitle:
          'Enter your email. If an account exists, reset instructions will be available.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_successMessage == null)
              _EmailField(controller: _email)
            else
              Container(
                key: const Key('forgot_success'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PulsePathColors.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    PulsePathSizes.controlRadius,
                  ),
                  border: Border.all(
                    color: PulsePathColors.cyan.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(_successMessage!, textAlign: TextAlign.center),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorText(_error!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('forgot_submit_button'),
              onPressed: _loading
                  ? null
                  : _successMessage == null
                  ? _submit
                  : () => widget.onSubmitted(_developmentToken),
              child: _loading
                  ? const _ButtonProgress()
                  : Text(
                      _successMessage == null
                          ? 'Continue'
                          : 'Enter reset token',
                    ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading ? null : widget.onBack,
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    required this.onBack,
    required this.onComplete,
    this.initialToken,
    super.key,
  });
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final String? initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _token;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: _token.text, newPassword: _password.text);
      if (mounted) widget.onComplete();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      eyebrow: 'RESET PASSWORD',
      title: 'Create a fresh key.',
      subtitle: 'Paste your reset token and choose a new password.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('reset_token'),
              controller: _token,
              decoration: const InputDecoration(labelText: 'Reset token'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your reset token.'
                  : null,
            ),
            const SizedBox(height: 14),
            _PasswordField(
              key: const Key('reset_password'),
              controller: _password,
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
              validateLength: true,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('reset_confirm_password'),
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
              validator: (value) =>
                  value != _password.text ? 'Passwords do not match.' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorText(_error!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('reset_submit_button'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const _ButtonProgress()
                  : const Text('Reset password'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading ? null : widget.onBack,
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/branding/pulsepath_logo.png',
                      width: 68,
                      height: 68,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: PulsePathColors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: PulsePathColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: PulsePathColors.surface,
                      borderRadius: BorderRadius.circular(
                        PulsePathSizes.heroCardRadius,
                      ),
                      border: Border.all(color: PulsePathColors.divider),
                      boxShadow: [
                        BoxShadow(
                          color: PulsePathColors.violet.withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextFormField(
    key: const Key('email_field'),
    controller: controller,
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.next,
    autocorrect: false,
    decoration: const InputDecoration(labelText: 'Email'),
    validator: (value) {
      final email = value?.trim() ?? '';
      return !email.contains('@') ||
              email.startsWith('@') ||
              email.endsWith('@')
          ? 'Enter a valid email address.'
          : null;
    },
  );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.validateLength = false,
    super.key,
  });
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final bool validateLength;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    textInputAction: TextInputAction.done,
    decoration: InputDecoration(
      labelText: validateLength ? 'Password (8+ characters)' : 'Password',
      suffixIcon: IconButton(
        tooltip: obscure ? 'Show password' : 'Hide password',
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Enter your password.';
      }
      if (validateLength && value.length < 8) {
        return 'Password must be at least 8 characters.';
      }
      return null;
    },
  );
}

class _AuthLink extends StatelessWidget {
  const _AuthLink({
    required this.prompt,
    required this.action,
    required this.onPressed,
  });
  final String prompt;
  final String action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        prompt,
        style: const TextStyle(color: PulsePathColors.textSecondary),
      ),
      TextButton(onPressed: onPressed, child: Text(action)),
    ],
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Text(
    message,
    key: const Key('auth_error'),
    textAlign: TextAlign.center,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: PulsePathColors.background,
    ),
  );
}
