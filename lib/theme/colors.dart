import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  SMART BILLING SOFTWARE — BALANCED ELEGANT SAAS/POS COLOR SYSTEM
/// ─────────────────────────────────────────────────────────────────────────────
///  Perfect balanced palette ("In the middle") combining a rich slate charcoal
///  sidebar with high-visibility silver typography and vibrant action colors:
///
///  1. PRIMARY (Royal Sapphire Blue):    Color(0xFF3B82F6) - Main Actions & Active Highlights
///  2. SECONDARY (Fresh Emerald Green):  Color(0xFF10B981) - Financial Revenue & Paid States
///  3. TERTIARY (Sunset Amber):          Color(0xFFF59E0B) - Highlights & Category Badges
/// ─────────────────────────────────────────────────────────────────────────────

abstract class AppBrandColors {
  /// Primary Color: Royal Sapphire Blue — Dominant brand & main action color
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);

  /// Secondary Color: Fresh Emerald Green — Financial totals, success, paid bills & cash
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryDark = Color(0xFF047857);
  static const Color secondaryLight = Color(0xFFECFDF5);

  /// Tertiary Color: Sunset Amber — Highlights, active chips, pending orders & warnings
  static const Color tertiary = Color(0xFFF59E0B);
  static const Color tertiaryDark = Color(0xFFB45309);
  static const Color tertiaryLight = Color(0xFFFFFBEB);
}

class AppColors {
  // ── 3 Core Primary Software Colors ──────────────────────────────────────────
  static const Color kPrimary = Color(0xFF3B82F6);
  static const Color kSecondary = Color(0xFF10B981);
  static const Color kTertiary = Color(0xFFF59E0B);

  // ── Functional Brand Aliases ────────────────────────────────────────────────
  static const Color kBlue = Color(0xFF3B82F6);          // Primary Royal Sapphire Blue
  static const Color kDarkBlue = Color(0xFF1D4ED8);      // Deeper Navy Accent
  static const Color kLightBlue = Color(0xFFEFF6FF);     // Soft Azure Tint Background

  static const Color kGreen = Color(0xFF10B981);         // Fresh Emerald Green
  static const Color kDarkGreen = Color(0xFF047857);
  static const Color kLightGreen = Color(0xFFECFDF5);

  static const Color kOrange = Color(0xFFF59E0B);        // Sunset Amber
  static const Color kDarkOrange = Color(0xFFB45309);
  static const Color kLightOrange = Color(0xFFFFFBEB);

  static const Color kRed = Color(0xFFEF4444);           // Soft Crimson Red
  static const Color kLightRed = Color(0xFFFEF2F2);
  static const Color kPurple = Color(0xFF8B5CF6);        // Royal Violet Accent

  // ── Neutral Surfaces & Typography ─────────────────────────────────────────
  static const Color kBgGray = Color(0xFFF8FAFC);        // Ultra-clean Cool Light Background
  static const Color kWhite = Colors.white;               // Pure Crisp White Surface
  static const Color kCardBg = Colors.white;

  static const Color kTextDark = Color(0xFF0F172A);      // Deep Slate Charcoal Header Text
  static const Color kTextGray = Color(0xFF475569);      // Slate Body Text
  static const Color kSubtext = Color(0xFF64748B);       // Muted Text
  static const Color kDivider = Color(0xFFE2E8F0);       // Soft Border & Divider Line

  // ── Balanced Rich Slate Sidebar Theme ("In the Middle") ───────────────────
  static const Color kSidebarBg = Color(0xFF1E293B);     // Rich Slate Charcoal Sidebar (Balanced)
  static const Color kSidebarHeader = Color(0xFF0F172A); // Dark Slate Header Container
  static const Color kSidebarActive = Color(0xFF3B82F6); // Solid Royal Blue Active Badge
  static const Color kSidebarText = Color(0xFFCBD5E1);   // High-Visibility Light Silver Inactive Text
  static const Color kSidebarActiveText = Colors.white;  // Pure White Active Text & Icon
}

// ── Global Top-Level Color Constants for Backward Compatibility ───────────────
const Color kBlue          = AppColors.kBlue;
const Color kDarkBlue      = AppColors.kDarkBlue;
const Color kLightBlue     = AppColors.kLightBlue;
const Color kGreen         = AppColors.kGreen;
const Color kOrange        = AppColors.kOrange;
const Color kRed           = AppColors.kRed;
const Color kPurple        = AppColors.kPurple;

const Color kBgGray        = AppColors.kBgGray;
const Color kWhite         = AppColors.kWhite;
const Color kTextDark      = AppColors.kTextDark;
const Color kTextGray      = AppColors.kTextGray;
const Color kSubtext       = AppColors.kSubtext;
const Color kDivider       = AppColors.kDivider;

const Color kSidebarBg     = AppColors.kSidebarBg;
const Color kSidebarActive = AppColors.kSidebarActive;
const Color kSidebarText   = AppColors.kSidebarText;