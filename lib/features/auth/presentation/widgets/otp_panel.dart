import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../../../../core/theme/prototype_visuals.dart';

/// Prototype-style OTP entry: verified icon, 6-digit field, cooldown resend.
class OtpPanel extends StatefulWidget {
  const OtpPanel({
    super.key,
    required this.otpController,
    required this.otpFieldKey,
    required this.verifyLabel,
    required this.onVerify,
    this.onResend,
    this.validator,
    this.busy = false,
  });

  final TextEditingController otpController;
  final GlobalKey<FormFieldState<String>> otpFieldKey;
  final String verifyLabel;
  final Future<void> Function() onVerify;
  final Future<void> Function()? onResend;
  final FormFieldValidator<String>? validator;
  final bool busy;

  @override
  State<OtpPanel> createState() => _OtpPanelState();
}

class _OtpPanelState extends State<OtpPanel> {
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resend() async {
    final onResend = widget.onResend;
    if (onResend == null || _resendSeconds > 0) return;
    await onResend();
    if (mounted) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PrototypeVisuals.softIconBg,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppTheme.brand,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.otpSent,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: widget.otpFieldKey,
          controller: widget.otpController,
          enabled: !widget.busy,
          validator: widget.validator,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
            color: AppTheme.ink,
          ),
          decoration: InputDecoration(
            labelText: l10n.otpPlaceholder,
            prefixIcon: const Icon(Icons.password_rounded),
            counterText: '',
            filled: true,
            fillColor: AppTheme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppTheme.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppTheme.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppTheme.brand, width: 1.5),
            ),
          ),
          onFieldSubmitted: (_) => widget.onVerify(),
        ),
        const SizedBox(height: 14),
        PrototypeButton(
          label: widget.verifyLabel,
          onPressed: widget.busy ? null : widget.onVerify,
          icon: Icons.arrow_forward_rounded,
        ),
        if (widget.onResend != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _resendSeconds > 0 ? null : _resend,
            child: Text(
              _resendSeconds > 0
                  ? 'Resend code in ${_resendSeconds}s'
                  : l10n.resendOtp,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}
