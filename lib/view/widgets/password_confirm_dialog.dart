import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/service/api_service.dart';
import 'package:test_bill/theme/colors.dart';

/// Prompts the user for the separate **Edit & Delete Password** (independent of
/// their login password) before allowing sensitive Edit or Delete operations.
/// If no separate Edit & Delete password has been configured yet, guides the
/// owner to set one right inside the dialog (authorized by their login password).
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
  final TextEditingController _loginPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmNewCtrl = TextEditingController();

  bool _checkingStatus = true;
  bool _needsSetup = false;
  bool _obscure = true;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final isSet = await ApiService.instance.hasActionPassword();
      if (mounted) {
        setState(() {
          _needsSetup = !isSet;
          _checkingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _needsSetup = false;
          _checkingStatus = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmNewCtrl.dispose();
    super.dispose();
  }

  String? _currentUserEmail() {
    if (Get.isRegistered<AuthController>()) {
      return Get.find<AuthController>().currentUser.value?['email']?.toString();
    }
    return null;
  }

  Future<void> _submitVerify() async {
    final pwd = _passwordCtrl.text;
    if (pwd.isEmpty) {
      setState(() => _error = 'Please enter the Edit & Delete password');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final ok = await ApiService.instance.verifyActionPassword(pwd);
      if (ok && mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 412) {
          setState(() {
            _needsSetup = true;
            _error = 'No separate Edit & Delete password is set yet. Create one below.';
          });
        } else {
          setState(() {
            _error = e.statusCode == 401
                ? 'Incorrect Edit & Delete password. Please try again.'
                : e.message;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Verification failed: $e');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _submitSetup() async {
    final loginPwd = _loginPasswordCtrl.text;
    final newPwd = _newPasswordCtrl.text;
    final confirmPwd = _confirmNewCtrl.text;

    if (loginPwd.isEmpty) {
      setState(() => _error = 'Enter your account login password to authorize');
      return;
    }
    if (newPwd.trim().length < 4) {
      setState(() => _error = 'Edit & Delete password must be at least 4 characters');
      return;
    }
    if (newPwd != confirmPwd) {
      setState(() => _error = 'New Edit & Delete passwords do not match');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await ApiService.instance.setActionPassword(
        loginPassword: loginPwd,
        newPassword: newPwd,
        fallbackEmail: _currentUserEmail(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to set password: $e');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  InputDecoration _dec(String hint, Color accent, {bool showEye = false}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
        prefixIcon: const Icon(Icons.key_rounded, size: 18, color: kTextGray),
        suffixIcon: showEye
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 18,
                  color: kTextGray,
                ),
              )
            : null,
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
      );

  @override
  Widget build(BuildContext context) {
    final accent = _needsSetup ? kBlue : (widget.isDestructive ? kRed : kBlue);

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
              _needsSetup ? 'Set Edit & Delete Password' : widget.title,
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
        width: 390,
        child: _checkingStatus
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator(color: kBlue)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_needsSetup) ...[
                    const Text(
                      'Create a separate Edit & Delete password (independent from your login password). '
                      'You can change this anytime in Settings.',
                      style: TextStyle(fontSize: 12.5, color: kTextGray, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Account Login Password (to authorize) *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _loginPasswordCtrl,
                      obscureText: _obscure,
                      autofocus: true,
                      enabled: !_verifying,
                      decoration: _dec('Enter your login password', accent, showEye: true),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'New Edit & Delete Password *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newPasswordCtrl,
                      obscureText: _obscure,
                      enabled: !_verifying,
                      decoration: _dec('Min 4 characters (separate PIN/password)', accent),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Confirm Edit & Delete Password *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmNewCtrl,
                      obscureText: _obscure,
                      enabled: !_verifying,
                      onSubmitted: (_) => _submitSetup(),
                      decoration: _dec('Re-enter Edit & Delete password', accent),
                    ),
                  ] else ...[
                    Text(
                      widget.message.replaceAll('login password', 'Edit & Delete password'),
                      style: const TextStyle(fontSize: 13, color: kTextGray, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Edit & Delete Password *',
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
                      onSubmitted: (_) => _submitVerify(),
                      decoration: _dec('Enter Edit & Delete password', accent, showEye: true),
                    ),
                  ],
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
          onPressed: (_checkingStatus || _verifying)
              ? null
              : (_needsSetup ? _submitSetup : _submitVerify),
          icon: _verifying
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kWhite),
                )
              : const Icon(Icons.verified_user_rounded, size: 16),
          label: Text(
            _verifying
                ? 'Saving...'
                : (_needsSetup ? 'Set & Continue' : widget.confirmLabel),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
