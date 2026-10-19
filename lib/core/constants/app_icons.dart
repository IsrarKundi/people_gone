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
/// Migrated so far: the core widgets. Feature screens migrate against
/// this same table (see ANTIGRAVITY-HANDOFF.md for the full mapping).
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
}
