import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class EmailAuthSheet extends ConsumerStatefulWidget {
  const EmailAuthSheet({super.key});

  @override
  ConsumerState<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends ConsumerState<EmailAuthSheet> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  int _cooldownLeft = 0;
  Timer? _timer;
  String? _error;
  String? _devOtp;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldownLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldownLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldownLeft = 0);
      } else {
        if (mounted) setState(() => _cooldownLeft--);
      }
    });
  }

  Future<void> _requestOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.requestEmailOTP(email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _loading = false;
        _devOtp = result.developmentOtp;
        if (_devOtp != null && _devOtp!.isNotEmpty) {
          _otpController.text = _devOtp!;
        }
      });
      _startCooldown(result.cooldownSeconds);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not request OTP. Please try again.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Enter 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final session = await repo.verifyEmailOTP(email, otp);
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).setSession(session);
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Invalid verification code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Email OTP Sign In / Sign Up',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                tooltip: 'Close sheet',
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _otpSent
                ? 'Enter the 6-digit code sent to ${_emailController.text.trim()}'
                : 'Enter your email address. We\'ll send a secure code to sign you in or create your account automatically.',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (!_otpSent)
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email Address *',
                hintText: 'alex@company.com',
                prefixIcon: const Icon(Icons.email_outlined, color: PulsePathColors.violet),
                filled: true,
                fillColor: const Color(0xFF1E1E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            )
          else
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                labelText: '6-Digit Code *',
                hintText: '123456',
                prefixIcon: const Icon(Icons.shield_outlined, color: PulsePathColors.violet),
                filled: true,
                fillColor: const Color(0xFF1E1E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : (_otpSent ? _verifyOtp : _requestOtp),
            style: ElevatedButton.styleFrom(
              backgroundColor: PulsePathColors.violet,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _otpSent ? 'Verify & Continue' : 'Send Code',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
          if (_otpSent) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _cooldownLeft > 0 || _loading ? null : _requestOtp,
              child: Text(
                _cooldownLeft > 0 ? 'Resend code in ${_cooldownLeft}s' : 'Resend Code',
                style: TextStyle(
                  color: _cooldownLeft > 0 ? Colors.white38 : PulsePathColors.violet,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
