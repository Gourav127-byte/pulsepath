import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/pulse_path_theme.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class PhoneAuthSheet extends ConsumerStatefulWidget {
  const PhoneAuthSheet({super.key});

  @override
  ConsumerState<PhoneAuthSheet> createState() => _PhoneAuthSheetState();
}

class _PhoneAuthSheetState extends ConsumerState<PhoneAuthSheet> {
  final _phoneController = TextEditingController();
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
    _phoneController.dispose();
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
    var phone = _phoneController.text.trim();
    if (!phone.startsWith('+') && phone.length == 10) {
      phone = '+91$phone';
    }
    if (phone.isEmpty || phone.length < 7) {
      setState(
        () => _error =
            'Enter a valid phone number with country code (e.g. +919876543210)',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.requestPhoneOTP(phone);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _devOtp = result.developmentOtp;
          if (_devOtp != null) {
            _otpController.text = _devOtp!;
          }
        });
        _startCooldown(result.cooldownSeconds);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not request OTP. Check network connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    var phone = _phoneController.text.trim();
    if (!phone.startsWith('+') && phone.length == 10) {
      phone = '+91$phone';
    }
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Enter the complete 6-digit verification code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final session = await repo.verifyPhoneOTP(phone, otp);
      ref.read(authControllerProvider.notifier).setSession(session);
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Verification failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PulsePathColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _otpSent ? 'Enter Verification Code' : 'Phone Verification',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _otpSent
                  ? 'We sent a 6-digit SMS verification code to ${_phoneController.text}.'
                  : 'Enter your mobile phone number with country code.',
              style: const TextStyle(
                color: PulsePathColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            if (!_otpSent) ...[
              TextFormField(
                key: const Key('phone_number_input'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (e.g. +919876543210)',
                  hintText: '+919876543210',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ] else ...[
              TextFormField(
                key: const Key('phone_otp_input'),
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-Digit Verification Code',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('phone_auth_error'),
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: Key(_otpSent ? 'verify_otp_button' : 'request_otp_button'),
              onPressed: _loading
                  ? null
                  : (_otpSent ? _verifyOtp : _requestOtp),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PulsePathColors.background,
                      ),
                    )
                  : Text(_otpSent ? 'Verify Code' : 'Send Code'),
            ),
            if (_otpSent) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                            _otpSent = false;
                            _error = null;
                          }),
                    child: const Text('Change Phone Number'),
                  ),
                  TextButton(
                    onPressed: (_loading || _cooldownLeft > 0)
                        ? null
                        : _requestOtp,
                    child: Text(
                      _cooldownLeft > 0
                          ? 'Resend in ${_cooldownLeft}s'
                          : 'Resend Code',
                      style: TextStyle(
                        color: _cooldownLeft > 0
                            ? PulsePathColors.textSecondary
                            : PulsePathColors.cyan,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
