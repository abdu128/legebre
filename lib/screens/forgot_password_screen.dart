import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialPhone = ''});

  final String initialPhone;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizeEthiopiaPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('251')) return digits;
    if (digits.startsWith('0') && digits.length == 10) {
      return '251${digits.substring(1)}';
    }
    if (digits.length == 9 && digits.startsWith('9')) {
      return '251$digits';
    }
    return digits;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final phone = _normalizeEthiopiaPhone(_phoneController.text.trim());
    try {
      await appState.requestPasswordReset(phone);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Check your phone for the verification code.'),
          ),
        ),
      );
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(phone: phone)),
      );
      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop(result);
      }
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Something went wrong. Try again.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Recover your account'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    "Enter the phone number you use for Legebere and we'll send you a 6-digit code.",
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('Phone number'),
                    prefixText: '+251 ',
                    prefixIcon: const Icon(Icons.phone_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('Phone number is required');
                    }
                    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                    final normalized = digits.startsWith('251')
                        ? digits
                        : (digits.length == 9 && digits.startsWith('9')
                            ? '251$digits'
                            : digits);
                    if (!normalized.startsWith('2519') ||
                        normalized.length != 12) {
                      return context.tr('Phone must start with 2519');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(context.tr('Send reset code')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.phone});

  final String phone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _resending = false;
  Duration _remaining = const Duration(minutes: 10);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remaining = const Duration(minutes: 10);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining.inSeconds <= 1) {
        setState(() {
          _remaining = Duration.zero;
        });
        timer.cancel();
      } else {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
      }
    });
  }

  bool get _canSubmit {
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    return !_submitting &&
        otp.length == 6 &&
        password.length >= 8 &&
        confirm == password;
  }

  String get _formattedRemaining {
    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate() || !_canSubmit) return;
    setState(() => _submitting = true);
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.resetPassword(
        otp: _otpController.text.trim(),
        password: _passwordController.text,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Password updated successfully'))),
      );
      if (!mounted) return;
      Navigator.of(context).pop(widget.phone);
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Something went wrong. Try again.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resending || _remaining.inSeconds > 0) return;
    setState(() => _resending = true);
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.requestPasswordReset(widget.phone);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('We just sent you a new code.'))),
      );
      if (!mounted) return;
      _startTimer();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Something went wrong. Try again.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = _remaining == Duration.zero && !_resending;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Reset password'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  context.tr('Enter the 6-digit code sent to your phone'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: context.tr('Verification code'),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length != 6) {
                      return context.tr('Enter the 6-digit code');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: context.tr('New password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.length < 8 ||
                        !RegExp(r'[a-z]').hasMatch(password) ||
                        !RegExp(r'[A-Z]').hasMatch(password) ||
                        !RegExp(r'\d').hasMatch(password) ||
                        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
                      return context.tr('Use 8+ characters with uppercase, lowercase, number, and symbol');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: context.tr('Confirm new password'),
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.length < 8 ||
                        !RegExp(r'[a-z]').hasMatch(password) ||
                        !RegExp(r'[A-Z]').hasMatch(password) ||
                        !RegExp(r'\d').hasMatch(password) ||
                        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
                      return context.tr('Use 8+ characters with uppercase, lowercase, number, and symbol');
                    }
                    if (value != _passwordController.text) {
                      return context.tr('Passwords do not match');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${context.tr('Code expires in')} $_formattedRemaining',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: canResend ? _resendCode : null,
                    icon: _resending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(context.tr('Resend code')),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _canSubmit ? _handleReset : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.tr('Reset password')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
