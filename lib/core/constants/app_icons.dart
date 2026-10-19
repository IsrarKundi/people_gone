import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// The app's single icon system (audit 2026-10-19): **Phosphor Icons**
/// via the `phosphoricons_flutter` icon font (MIT licence). Every icon
/// in the app resolves through this file — feature code never names
/// `Icons.*` or `PhosphorIcons*` directly, so a glyph can be re-chosen
/// in exactly one place.
///
/// Weight rules (from the icon research):
/// - **Regular** is the default for all UI icons.
/// - **Fill** marks a selected / active state only.
/// - **Duotone** is reserved for a few premium accent spots, decided
///   per screen — none in core yet.
///
/// Migrated so far: core widgets (original) + all feature screens
/// (Task 1, 2026-10-19, per ANTIGRAVITY-HANDOFF.md concept mapping).
abstract final class AppIcons {
  /// Errors / warning surfaces (was Material `error_outline`).
  static const IconData error = PhosphorIconsRegular.warningCircle;

  /// Generic photo-library placeholder (was `photo_library_outlined`).
  static const IconData photoLibrary = PhosphorIconsRegular.images;

  /// Privacy / trust marker (was `privacy_tip_outlined`).
  static const IconData privacy = PhosphorIconsRegular.shieldCheck;

  /// Encryption / locked (was `lock_outline`).
  static const IconData lock = PhosphorIconsRegular.lock;

  /// Protection / never-trained marker (was `shield_outlined`).
  static const IconData shield = PhosphorIconsRegular.shield;

  /// Automatic deletion (was `auto_delete_outlined`).
  static const IconData autoDelete = PhosphorIconsRegular.trash;

  /// A person (thumbnail placeholder; was `person`).
  static const IconData person = PhosphorIconsRegular.user;

  /// Confirm / kept (was `check`).
  static const IconData check = PhosphorIconsRegular.check;

  /// Dismiss / removed (was `close`).
  static const IconData close = PhosphorIconsRegular.x;

  // ─── Feature-screen icons added in Task 1 (2026-10-19) ──────────────

  /// Photo pick / camera  (was `add_photo_alternate_rounded`).
  static const IconData camera = PhosphorIconsRegular.camera;

  /// Navigate back / left  (was `arrow_back_rounded`).
  static const IconData caretLeft = PhosphorIconsRegular.caretLeft;

  /// Navigate forward / right  (was `chevron_right`, `chevron_right_rounded`).
  static const IconData caretRight = PhosphorIconsRegular.caretRight;

  /// Broken / missing image placeholder  (was `broken_image_outlined`).
  static const IconData brokenImage = PhosphorIconsRegular.imageBroken;

  /// Success badge — **Fill weight**; selected/active only
  /// (was `check_circle_rounded`, `check_circle`).
  static const IconData checkCircleFill = PhosphorIconsFill.checkCircle;

  /// Saved-state check — **Fill weight**; receipt confirmation only
  /// (was `check_rounded` on the save button).
  static const IconData checkFill = PhosphorIconsFill.check;

  /// Trash / delete  (was `delete_outline`).
  static const IconData trash = PhosphorIconsRegular.trash;

  /// Before/after compare — ONE glyph everywhere (unifies
  /// `compare`, `compare_arrows`, `compare_arrows_rounded`, `swap_horiz`).
  static const IconData arrowsLeftRight = PhosphorIconsRegular.arrowsLeftRight;

  /// Undo / step back  (was `undo`).
  static const IconData arrowCounterClockwise =
      PhosphorIconsRegular.arrowCounterClockwise;

  /// Info / overlap-risk note  (was `info_outline`).
  static const IconData info = PhosphorIconsRegular.info;

  /// Item / ambiguous-object placeholder  (was `inventory_2_outlined`).
  static const IconData stack = PhosphorIconsRegular.stack;

  /// Processing provider display  (was `dns_outlined`).
  static const IconData database = PhosphorIconsRegular.database;

  /// Diagnostics / bug report  (was `bug_report_outlined`).
  static const IconData bug = PhosphorIconsRegular.bugBeetle;

  /// Free-saves / savings counter  (was `savings_outlined`).
  static const IconData piggyBank = PhosphorIconsRegular.piggyBank;

  /// Person removal  (was `person_remove`).
  static const IconData userMinus = PhosphorIconsRegular.userMinus;

  /// Manual brush tool  (was `brush`).
  static const IconData paintBrush = PhosphorIconsRegular.paintBrush;

  /// Fix / wand  (was `auto_fix_high`).
  static const IconData magicWand = PhosphorIconsRegular.magicWand;

  /// Eraser  (was `cleaning_services`).
  static const IconData eraser = PhosphorIconsRegular.eraser;

  /// History  (was `history`).
  static const IconData clockCounterClockwise =
      PhosphorIconsRegular.clockCounterClockwise;

  /// Share photo  (was `share`).
  static const IconData shareNetwork = PhosphorIconsRegular.shareNetwork;

  /// Settings  (was `settings_outlined`).
  static const IconData gear = PhosphorIconsRegular.gear;
}
