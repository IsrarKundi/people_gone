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
    required this.useGateway,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
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
      useGateway: bool.fromEnvironment('USE_GATEWAY', defaultValue: true),
      supabaseUrl: String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://ietwddgjtcrabqjdxsfp.supabase.co',
      ),
      supabaseAnonKey: String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlldHdkZGdqdGNyYWJxamR4c2ZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5MTk1NjMsImV4cCI6MjEwNzQ5NTU2M30.xwxkK9U3aXJd-GTVFNNJRKFw91aKrbQ1XerPe2PO9n4',
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

  /// Phase 2 (§7): when true the app talks to the Supabase gateway
  /// (anonymous auth + jobs + server credit ledger); when false it uses
  /// the direct dev-worker implementation. The gateway is the only
  /// production path (AGENTS.md) — the direct path remains for local
  /// worker development via --dart-define.
  final bool useGateway;

  /// Supabase project URL (gateway + anonymous auth live under it).
  final String supabaseUrl;

  /// Supabase anon (public client) key. This is the PUBLIC key by
  /// design — RLS + the gateway functions are the security boundary.
  /// The service_role key must NEVER appear in the app or this repo.
  final String supabaseAnonKey;

  /// Base URL of the gateway Edge Functions.
  String get gatewayBaseUrl => '$supabaseUrl/functions/v1';
}
