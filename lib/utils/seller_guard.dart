import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

class SellerGuard {
  const SellerGuard._();

  static bool _hasSellerPrivileges(String? role) {
    if (role == null) return false;
    final normalized = role.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains('seller') || normalized.contains('admin');
  }

  static bool _isBuyer(String? role) {
    if (role == null) return false;
    final normalized = role.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains('buyer');
  }

  static Future<bool> ensureSeller(BuildContext context) async {
    final appState = context.read<AppState>();
    final user = appState.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please log in to continue'))),
      );
      return false;
    }

    if (_hasSellerPrivileges(user.role)) return true;
    if (!_isBuyer(user.role)) return true;

    final whatsapp = await _promptWhatsapp(context, user);
    if (whatsapp == null) return false;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await appState.api.updateProfile({
        'role': 'SELLER',
        'whatsapp': whatsapp,
      });
      await appState.refreshProfile();
      rootNavigator.pop();
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Seller upgrade success'))),
      );
      return true;
    } on ApiException catch (error) {
      rootNavigator.pop();
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (error.message.isNotEmpty)
                ? error.message
                : context.tr('Seller upgrade failure'),
          ),
        ),
      );
      return false;
    } catch (_) {
      rootNavigator.pop();
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Seller upgrade failure'))),
      );
      return false;
    }
  }

  static Future<String?> _promptWhatsapp(
    BuildContext context,
    AppUser user,
  ) async {
    final existingWhatsapp = user.whatsapp?.trim();
    final controller = TextEditingController(
      text: (existingWhatsapp != null && existingWhatsapp.isNotEmpty)
          ? existingWhatsapp
          : (user.phone ?? ''),
    );
    try {
      String? errorText;
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setState) {
              return AlertDialog(
                title: Text(dialogContext.tr('Become a seller')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dialogContext.tr('Seller upgrade description')),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: dialogContext.tr('WhatsApp number'),
                        errorText: errorText,
                        prefixIcon: const Icon(Icons.chat_rounded),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(null),
                    child: Text(dialogContext.tr('Maybe later')),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        setState(() {
                          errorText = dialogContext.tr(
                            'WhatsApp number is required',
                          );
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(value);
                    },
                    child: Text(dialogContext.tr('Become a seller')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }
}
