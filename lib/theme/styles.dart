import 'package:flutter/material.dart';
import 'package:test_bill/theme/colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  SMART BILLING SOFTWARE — UNIFIED TYPOGRAPHY & UI STYLE SYSTEM
/// ─────────────────────────────────────────────────────────────────────────────
///  Provides a single source of truth for text styles, card decorations,
///  input field themes, button styles, shadows, and spacing across the app.
/// ─────────────────────────────────────────────────────────────────────────────

abstract class AppStyles {
  // ── Border Radii ────────────────────────────────────────────────────────────
  static final BorderRadius radiusSmall = BorderRadius.circular(8);
  static final BorderRadius radiusMedium = BorderRadius.circular(12);
  static final BorderRadius radiusLarge = BorderRadius.circular(16);
  static final BorderRadius radiusXLarge = BorderRadius.circular(20);

  // ── Box Shadows ────────────────────────────────────────────────────────────
  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x1F0F172A),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // ── Standard Container / Card Decorations ───────────────────────────────
  static final BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.kWhite,
    borderRadius: radiusMedium,
    border: Border.all(color: AppColors.kDivider),
    boxShadow: subtleShadow,
  );

  static final BoxDecoration activeCardDecoration = BoxDecoration(
    color: AppColors.kWhite,
    borderRadius: radiusMedium,
    border: Border.all(color: AppColors.kBlue, width: 1.5),
    boxShadow: cardShadow,
  );

  static final BoxDecoration elevatedCardDecoration = BoxDecoration(
    color: AppColors.kWhite,
    borderRadius: radiusLarge,
    boxShadow: cardShadow,
  );

  // ── Input Decoration Helpers ─────────────────────────────────────────────
  static InputDecoration inputDecoration({
    required String hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: hintText,
      labelText: labelText,
      hintStyle: bodyTextMuted,
      labelStyle: bodyTextMuted,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.kBgGray,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: radiusMedium,
        borderSide: const BorderSide(color: AppColors.kDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radiusMedium,
        borderSide: const BorderSide(color: AppColors.kDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radiusMedium,
        borderSide: const BorderSide(color: AppColors.kBlue, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radiusMedium,
        borderSide: const BorderSide(color: AppColors.kRed),
      ),
    );
  }

  // ── Button Styles ──────────────────────────────────────────────────────────
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.kBlue,
    foregroundColor: AppColors.kWhite,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: radiusMedium),
    textStyle: buttonText,
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.kTextDark,
    side: const BorderSide(color: AppColors.kDivider),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: radiusMedium),
    textStyle: buttonText,
  );

  static final ButtonStyle successButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.kGreen,
    foregroundColor: AppColors.kWhite,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: radiusMedium),
    textStyle: buttonText,
  );

  static final ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.kRed,
    foregroundColor: AppColors.kWhite,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: radiusMedium),
    textStyle: buttonText,
  );

  // ── Typography Styles ─────────────────────────────────────────────────────
  static const TextStyle pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.kTextDark,
    letterSpacing: -0.4,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.kTextDark,
    letterSpacing: -0.2,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.kTextDark,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.kTextDark,
    letterSpacing: -0.5,
  );

  static const TextStyle statValuePrimary = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.kBlue,
    letterSpacing: -0.5,
  );

  static const TextStyle statValueSuccess = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.kGreen,
    letterSpacing: -0.5,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.kTextGray,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.kTextDark,
  );

  static const TextStyle bodyTextBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.kTextDark,
  );

  static const TextStyle bodyTextMuted = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.kTextGray,
  );

  static const TextStyle captionText = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: AppColors.kSubtext,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle chipText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
}
