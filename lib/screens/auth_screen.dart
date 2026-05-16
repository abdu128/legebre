import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';
import 'forgot_password_screen.dart';

enum AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.login;
  int _languageIndex = 0;
  bool _obscure = true;
  bool _submitting = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _otpSent = false;
  Duration _otpRemaining = Duration.zero;
  Timer? _otpTimer;
  String _role = 'BUYER';
  bool _syncedLocale = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();

  static const _languageOptions = [
    Locale('en'),
    Locale('am'),
    Locale('om'),
    Locale('so'),
  ];

  @override
  void dispose() {
    _otpTimer?.cancel();
    _nameController.dispose();
    _identifierController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == AuthMode.login ? AuthMode.register : AuthMode.login;
      _resetOtpState();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedLocale) return;
    final locale = context.read<AppState>().locale;
    final index = _languageOptions.indexWhere(
      (entry) => entry.languageCode == locale.languageCode,
    );
    if (index != -1) {
      _languageIndex = index;
    }
    _syncedLocale = true;
  }

  void _resetOtpState() {
    _otpTimer?.cancel();
    _otpRemaining = Duration.zero;
    _otpSent = false;
    _sendingOtp = false;
    _verifyingOtp = false;
    _otpController.clear();
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _otpRemaining = const Duration(seconds: 60);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpRemaining.inSeconds <= 1) {
        setState(() => _otpRemaining = Duration.zero);
        timer.cancel();
      } else {
        setState(() => _otpRemaining -= const Duration(seconds: 1));
      }
    });
  }

  String get _formattedOtpRemaining {
    final seconds = _otpRemaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '00:$seconds';
  }

  Future<void> _handleSubmit() async {
    if (_mode == AuthMode.login) {
      await _handleLoginAction();
      return;
    }

    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final appState = context.read<AppState>();
    final scaffold = ScaffoldMessenger.of(context);

    try {
      final trimmedWhatsapp = _whatsappController.text.trim();
      await appState.register(
        name: _nameController.text.trim(),
        password: _passwordController.text,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        whatsapp: _role == 'SELLER' && trimmedWhatsapp.isNotEmpty
            ? trimmedWhatsapp
            : null,
        role: _role,
      );
      scaffold.showSnackBar(
        SnackBar(content: Text(context.tr('Account created successfully'))),
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      scaffold.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      scaffold.showSnackBar(
        SnackBar(content: Text(context.tr('Something went wrong. Try again.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleLoginAction() async {
    if (_sendingOtp || _verifyingOtp) return;
    if (!_formKey.currentState!.validate()) return;

    if (_otpSent) {
      await _verifyLoginOtp();
    } else {
      await _sendLoginOtp();
    }
  }

  Future<void> _sendLoginOtp() async {
    if (_sendingOtp) return;
    setState(() => _sendingOtp = true);
    final appState = context.read<AppState>();
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await appState.requestLoginOtp(
        phone: _identifierController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startOtpTimer();
      scaffold.showSnackBar(
        SnackBar(content: Text(context.tr('We sent a login code to your phone'))),
      );
    } on ApiException catch (error) {
      scaffold.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      scaffold.showSnackBar(
        SnackBar(content: Text(context.tr('Something went wrong. Try again.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingOtp = false);
      }
    }
  }

  Future<void> _verifyLoginOtp() async {
    if (_verifyingOtp) return;
    setState(() => _verifyingOtp = true);
    final appState = context.read<AppState>();
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await appState.verifyLoginOtp(
        phone: _identifierController.text.trim(),
        otp: _otpController.text.trim(),
      );
      scaffold.showSnackBar(
        SnackBar(content: Text(context.tr('Welcome back!'))),
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      scaffold.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      scaffold.showSnackBar(
        SnackBar(content: Text(context.tr('Something went wrong. Try again.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _verifyingOtp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogin = _mode == AuthMode.login;
    final showWhatsappField = !isLogin && _role == 'SELLER';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F6EC), Color(0xFFF8FFF6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legebere',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepBrown,
                          ),
                        ),
                        Text(
                          context.tr('Welcome back'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    PopupMenuButton<int>(
                      initialValue: _languageIndex,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (value) {
                        setState(() => _languageIndex = value);
                        context.read<AppState>().setLocale(
                          _languageOptions[value],
                        );
                      },
                      itemBuilder: (context) =>
                          List.generate(_languageOptions.length, (index) {
                            final locale = _languageOptions[index];
                            return PopupMenuItem(
                              value: index,
                              child: Text(_languageLabel(context, locale)),
                            );
                          }),
                      child: Chip(
                        label: Text(
                          _languageLabel(
                            context,
                            _languageOptions[_languageIndex],
                          ),
                        ),
                        avatar: const Icon(Icons.language, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .05,
                                      ),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isLogin
                                                ? context.tr('Log in')
                                                : context.tr('Join Legebere'),
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          SegmentedButton<AuthMode>(
                                            showSelectedIcon: false,
                                            segments: [
                                              ButtonSegment(
                                                value: AuthMode.login,
                                                label: Text(
                                                  context.tr('Login'),
                                                ),
                                              ),
                                              ButtonSegment(
                                                value: AuthMode.register,
                                                label: Text(
                                                  context.tr('Register'),
                                                ),
                                              ),
                                            ],
                                            selected: {_mode},
                                            onSelectionChanged: (value) =>
                                                setState(
                                                  () => _mode = value.first,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      if (!isLogin) ...[
                                        TextFormField(
                                          controller: _nameController,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          decoration: InputDecoration(
                                            labelText: context.tr('Full name'),
                                            prefixIcon: const Icon(
                                              Icons.person,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return context.tr(
                                                'Name is required',
                                              );
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        DropdownButtonFormField<String>(
                                          value: _role,
                                          decoration: InputDecoration(
                                            labelText: context.tr('Role'),
                                            prefixIcon: const Icon(
                                              Icons.badge_outlined,
                                            ),
                                          ),
                                          items: [
                                            DropdownMenuItem(
                                              value: 'BUYER',
                                              child: Text(context.tr('Buyer')),
                                            ),
                                            DropdownMenuItem(
                                              value: 'SELLER',
                                              child: Text(context.tr('Seller')),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setState(() => _role = value);
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          decoration: InputDecoration(
                                            labelText: context.tr(
                                              'Email (optional)',
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.alternate_email_rounded,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          decoration: InputDecoration(
                                            labelText: context.tr(
                                              'Phone number',
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.phone_rounded,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (!isLogin &&
                                                (value == null ||
                                                    value.trim().isEmpty)) {
                                              return context.tr(
                                                'Phone number is required',
                                              );
                                            }
                                            if (!isLogin && value != null) {
                                              final digits = value.replaceAll(
                                                RegExp(r'[^0-9]'),
                                                '',
                                              );
                                              if (!digits.startsWith('2519') ||
                                                  digits.length != 12) {
                                                return context.tr(
                                                  'Phone must start with 2519',
                                                );
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        if (showWhatsappField) ...[
                                          TextFormField(
                                            controller: _whatsappController,
                                            keyboardType: TextInputType.phone,
                                            decoration: InputDecoration(
                                              labelText: context.tr(
                                                'WhatsApp number',
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.chat_rounded,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            validator: (value) {
                                              if (_role == 'SELLER' &&
                                                  (value == null ||
                                                      value.trim().isEmpty)) {
                                                return context.tr(
                                                  'WhatsApp number is required',
                                                );
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ],
                                      if (isLogin) ...[
                                        TextFormField(
                                          controller: _identifierController,
                                          keyboardType: TextInputType.phone,
                                          decoration: InputDecoration(
                                            labelText: context.tr(
                                              'Phone number',
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.phone_rounded,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (isLogin &&
                                                (value == null ||
                                                    value.trim().isEmpty)) {
                                              return context.tr(
                                                'Enter your phone number',
                                              );
                                            }
                                            if (isLogin && value != null) {
                                              final digits =
                                                  value.replaceAll(RegExp(r'[^0-9]'), '');
                                              if (!digits.startsWith('2519') ||
                                                  digits.length != 12) {
                                                return context.tr(
                                                  'Phone must start with 2519',
                                                );
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        if (_otpSent) ...[
                                          TextFormField(
                                            controller: _otpController,
                                            keyboardType: TextInputType.number,
                                            maxLength: 6,
                                            decoration: InputDecoration(
                                              labelText:
                                                  context.tr('Verification code'),
                                              counterText: '',
                                              prefixIcon: const Icon(
                                                Icons.verified_rounded,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            validator: (value) {
                                              if (_otpSent &&
                                                  (value == null ||
                                                      value.trim().length !=
                                                          6)) {
                                                return context.tr(
                                                  'Enter the 6-digit code',
                                                );
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _otpRemaining == Duration.zero
                                                    ? context
                                                        .tr('Resend code')
                                                    : '${context.tr('Code expires in')} $_formattedOtpRemaining',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors
                                                          .grey.shade600,
                                                    ),
                                              ),
                                              TextButton(
                                                onPressed: _otpRemaining ==
                                                            Duration.zero &&
                                                        !_sendingOtp
                                                    ? _sendLoginOtp
                                                    : null,
                                                child: Text(
                                                  context.tr('Resend code'),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ],
                                      if (!isLogin) ...[
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscure,
                                          decoration: InputDecoration(
                                            labelText: context.tr('Password'),
                                            prefixIcon: const Icon(
                                              Icons.lock_outline,
                                              color: Colors.grey,
                                            ),
                                            suffixIcon: IconButton(
                                              onPressed: () => setState(
                                                () => _obscure = !_obscure,
                                              ),
                                              icon: Icon(
                                                _obscure
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.length < 6) {
                                              return context.tr(
                                                'Use at least 6 characters',
                                              );
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                      ElevatedButton(
                                        onPressed: (_submitting ||
                                                _sendingOtp ||
                                                _verifyingOtp)
                                            ? null
                                            : _handleSubmit,
                                        child: (_submitting ||
                                                _sendingOtp ||
                                                _verifyingOtp)
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                isLogin
                                                    ? (_otpSent
                                                        ? context.tr(
                                                            'Verify & log in',
                                                          )
                                                        : context.tr(
                                                            'Send login code',
                                                          ))
                                                    : context.tr(
                                                        'Create account',
                                                      ),
                                              ),
                                      ),
                                      // const SizedBox(height: 12),
                                      // Align(
                                      //   alignment: Alignment.center,
                                      //   child: TextButton(
                                      //     onPressed: () {},
                                      //     child: Text(context.tr('Need help?')),
                                      //   ),
                                      // ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            isLogin
                                                ? context.tr(
                                                    "Don't have an account?",
                                                  )
                                                : context.tr(
                                                    'Already have an account?',
                                                  ),
                                          ),
                                          TextButton(
                                            onPressed: _submitting
                                                ? null
                                                : _toggleMode,
                                            child: Text(
                                              isLogin
                                                  ? context.tr('Sign up')
                                                  : context.tr('Log in'),
                                            ),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _languageLabel(BuildContext context, Locale locale) {
    switch (locale.languageCode) {
      case 'am':
        return context.tr('Amharic');
      case 'om':
        return context.tr('Afan Oromo');
      case 'so':
        return context.tr('Somali');
      default:
        return context.tr('English');
    }
  }

  Future<void> _openForgotPassword() async {
    final initial = _identifierController.text.contains('@')
        ? _identifierController.text.trim()
        : '';
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialEmail: initial),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _identifierController.text = result;
      });
    }
  }
}
