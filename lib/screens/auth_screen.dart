import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

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
  String _role = 'BUYER';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();

  final _languages = ['English', 'አማርኛ', 'Afan Oromo', 'Somali'];

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == AuthMode.login ? AuthMode.register : AuthMode.login;
    });
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final appState = context.read<AppState>();
    final scaffold = ScaffoldMessenger.of(context);

    try {
      if (_mode == AuthMode.login) {
        await appState.login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await appState.register(
          name: _nameController.text.trim(),
          password: _passwordController.text,
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          whatsapp: _whatsappController.text.trim().isEmpty
              ? null
              : _whatsappController.text.trim(),
          role: _role,
        );
      }
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            _mode == AuthMode.login
                ? 'Welcome back!'
                : 'Account created successfully',
          ),
        ),
      );
    } on ApiException catch (error) {
      scaffold.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
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
    final isLogin = _mode == AuthMode.login;

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
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.grass_rounded,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legebere',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const Text('Welcome back, farmer!'),
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
                      },
                      itemBuilder: (context) => List.generate(
                        _languages.length,
                        (index) => PopupMenuItem(
                          value: index,
                          child: Text(_languages[index]),
                        ),
                      ),
                      child: Chip(
                        label: Text(_languages[_languageIndex]),
                        avatar: const Icon(Icons.language, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .05),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isLogin ? 'Log in' : 'Join Legebere',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                SegmentedButton<AuthMode>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: AuthMode.login,
                                      label: Text('Login'),
                                    ),
                                    ButtonSegment(
                                      value: AuthMode.register,
                                      label: Text('Register'),
                                    ),
                                  ],
                                  selected: {_mode},
                                  onSelectionChanged: (value) =>
                                      setState(() => _mode = value.first),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (!isLogin) ...[
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _role,
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'BUYER',
                                    child: Text('Buyer'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'SELLER',
                                    child: Text('Seller'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ADMIN',
                                    child: Text('Admin'),
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
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email (optional)',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone number',
                                  prefixIcon: Icon(
                                    Icons.phone_rounded,
                                    color: Colors.grey,
                                  ),
                                ),
                                validator: (value) {
                                  if (!isLogin &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Phone number is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _whatsappController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'WhatsApp (optional)',
                                  prefixIcon: Icon(
                                    Icons.chat_rounded,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (isLogin) ...[
                              TextFormField(
                                controller: _identifierController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email or phone',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                    color: Colors.grey,
                                  ),
                                ),
                                validator: (value) {
                                  if (isLogin &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Enter your email or phone';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Use at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _submitting ? null : _handleSubmit,
                              child: _submitting
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(isLogin ? 'Log in' : 'Create account'),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text('Need help?'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLogin
                                      ? "Don't have an account?"
                                      : 'Already have an account?',
                                ),
                                TextButton(
                                  onPressed: _submitting ? null : _toggleMode,
                                  child: Text(isLogin ? 'Sign up' : 'Log in'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
