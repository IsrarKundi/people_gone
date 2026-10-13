/// Client configuration (Requirements §6 / AGENTS.md "Secrets & config").
///
/// Non-secret values ONLY, injected with `--dart-define-from-file` (see
/// `.env.example`). Prices never live here — they come from the store via
/// `PurchaseService`. The processing-provider display name comes from here,
/// never hard-coded in UI.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.providerDisplayName,
    required this.consentVersion,
    required this.supportEmail,
    required this.privacyPolicyUrl,
  });

  /// Loads config from dart-define values. The development default base
  /// URL is our own dev processing worker (Modal), which stands in for
  /// the Supabase gateway until Phase 2, Task 2.1 — the URL lives ONLY
  /// here (and in the dart-define override), never in feature code
  /// (API Contract v1, modal-deploy/API_CONTRACT.md).
  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue:
            'https://israrkundi--peoplegone-worker-web.us-east.modal.run',
      ),
      providerDisplayName: String.fromEnvironment(
        'PROVIDER_DISPLAY_NAME',
        defaultValue: "PeopleGone's processing servers",
      ),
      consentVersion: int.fromEnvironment('CONSENT_VERSION', defaultValue: 1),
      supportEmail: String.fromEnvironment(
        'SUPPORT_EMAIL',
        defaultValue: 'support@example.com',
      ),
      privacyPolicyUrl: String.fromEnvironment(
        'PRIVACY_POLICY_URL',
        defaultValue: 'https://example.invalid/privacy',
      ),
    );
  }

  /// Base URL of OUR gateway. The app never calls an AI/GPU vendor directly.
  final String apiBaseUrl;

  /// Human-readable processing-provider name used in disclosure copy.
  final String providerDisplayName;

  /// Consent copy version; bumping it re-shows the consent sheet (S2).
  final int consentVersion;

  final String supportEmail;
  final String privacyPolicyUrl;
}
