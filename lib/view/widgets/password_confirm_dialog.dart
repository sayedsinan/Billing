import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/service/api_service.dart';
import 'package:test_bill/theme/colors.dart';

/// Prompts the user for their login password before allowing sensitive
/// Edit or Delete operations. Returns `true` only after server-side verification.
class PasswordConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;

  const PasswordConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.isDestructive = false,
  });

  static Future<bool> verify(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
      ),
    );
    return result == true;
  }

  @override
  State<PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<PasswordConfirmDialog> {
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pwd = _passwordCtrl.text;
    if (pwd.isEmpty) {
      setState(() => _error = 'Please enter your login password');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      String? email;
      if (Get.isRegistered<AuthController>()) {
        email = Get.find<AuthController>().currentUser.value?['email']?.toString();
      }
      final ok = await ApiService.instance.verifyPassword(
        pwd,
        fallbackEmail: email,
      );
      if (ok && mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.statusCode == 401 ? 'Incorrect password. Please try again.' : e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Verification failed: $e');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDestructive ? kRed : kBlue;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
      actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock_outline_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: kTextDark,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: const TextStyle(fontSize: 13, color: kTextGray, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Login Password *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autofocus: true,
              enabled: !_verifying,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Enter your account password',
                hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                prefixIcon: const Icon(Icons.key_rounded, size: 18, color: kTextGray),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 18,
                    color: kTextGray,
                  ),
                ),
                filled: true,
                fillColor: kBgGray,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: kRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: kRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: kRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: kWhite,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _verifying ? null : _submit,
          icon: _verifying
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kWhite),
                )
              : const Icon(Icons.verified_user_rounded, size: 16),
          label: Text(
            _verifying ? 'Verifying...' : widget.confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
