import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import 'email_auth_sheet.dart';

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
  bool _rememberMe = true;

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
      title: 'Sign In',
      subtitle: 'Welcome back! Please enter your details to access your dashboard.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email Address Field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    text: 'Email Address ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(
                        text: '*',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('email_field'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'alex@company.com',
                    prefixIcon: Icon(Icons.email_outlined, color: PulsePathColors.violet),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return !email.contains('@') ||
                            email.startsWith('@') ||
                            email.endsWith('@')
                        ? 'Enter a valid email address.'
                        : null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Password Field & Forgot Password Link
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: const TextSpan(
                        text: 'Password ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: loading ? null : widget.onForgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PulsePathColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('login_password'),
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '••••••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: PulsePathColors.violet),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your password.';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Remember Me Row
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (val) => setState(() => _rememberMe = val ?? true),
                    activeColor: PulsePathColors.violet,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Remember me for faster sign in',
                    style: TextStyle(
                      fontSize: 13,
                      color: PulsePathColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (auth.message != null) ...[
              const SizedBox(height: 10),
              _ErrorText(auth.message!),
            ],
            const SizedBox(height: 18),

            // Sign In Button with Arrow
            FilledButton(
              key: const Key('login_button'),
              onPressed: loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: PulsePathColors.violet,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: loading
                  ? const _ButtonProgress()
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                      ],
                    ),
            ),
            const SizedBox(height: 18),

            // OR Divider
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 18),

            // Social Buttons Row (Google & Apple)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('google_signin_button'),
                    onPressed: loading ? null : _googleSignIn,
                    icon: const _GoogleLogoIcon(size: 18),
                    label: const Text('Google'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('apple_signin_button'),
                    onPressed: loading ? null : () {},
                    icon: const Icon(Icons.apple, size: 20, color: Colors.white),
                    label: const Text('Apple'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Email OTP Button
            OutlinedButton.icon(
              key: const Key('email_otp_auth_button'),
              onPressed: loading ? null : _openEmailAuth,
              icon: const Icon(Icons.mark_email_unread_rounded, size: 20),
              label: const Text('Sign in or Sign up with Email OTP'),
            ),
            const SizedBox(height: 20),

            // Footer CTA
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'No account? ',
                  style: TextStyle(color: PulsePathColors.textSecondary, fontSize: 13),
                ),
                GestureDetector(
                  onTap: loading ? null : widget.onSignUp,
                  child: const Text(
                    'Create account',
                    style: TextStyle(
                      color: PulsePathColors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
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
      title: 'Create Account',
      subtitle: 'Join PulsePath to track your steps, distance & daily scores.',
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
              decoration: const InputDecoration(
                labelText: 'Confirm password *',
                hintText: 'Re-enter your password',
                prefixIcon: Icon(Icons.lock_outline_rounded, color: PulsePathColors.violet),
              ),
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
                      fontWeight: FontWeight.bold,
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
          'Enter your email. If an account exists, reset instructions will be sent.',
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
              decoration: const InputDecoration(
                labelText: 'Reset token *',
                hintText: 'Paste token sent to email',
                prefixIcon: Icon(Icons.vpn_key_outlined, color: PulsePathColors.violet),
              ),
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
                labelText: 'Confirm new password *',
                hintText: 'Re-enter new password',
                prefixIcon: Icon(Icons.lock_outline_rounded, color: PulsePathColors.violet),
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
                  const SizedBox(height: 8),
                  Text(title, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: PulsePathColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 26),
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
    decoration: const InputDecoration(
      labelText: 'Email Address *',
      hintText: 'alex@company.com',
      prefixIcon: Icon(Icons.email_outlined, color: PulsePathColors.violet),
    ),
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
      labelText: validateLength ? 'Password (8+ characters) *' : 'Password *',
      hintText: '••••••••••••',
      prefixIcon: const Icon(Icons.lock_outline_rounded, color: PulsePathColors.violet),
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

class _GoogleLogoIcon extends StatelessWidget {
  const _GoogleLogoIcon({this.size = 18.0});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width / 2;
    final double strokeWidth = size.width * 0.22;
    final Rect rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: radius - strokeWidth / 2,
    );

    final Paint paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Paint paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Paint paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Paint paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, -0.4, 1.4, false, paintRed);
    canvas.drawArc(rect, 1.0, 1.1, false, paintYellow);
    canvas.drawArc(rect, 2.1, 1.4, false, paintGreen);
    canvas.drawArc(rect, 3.5, 1.2, false, paintBlue);

    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(cx - 1, cy - strokeWidth / 2, radius * 0.9, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
