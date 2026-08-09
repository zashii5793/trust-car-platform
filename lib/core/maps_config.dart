/// Google Maps configuration.
///
/// The API key is injected at build time via `--dart-define=MAPS_API_KEY=...`
/// (never hardcoded / committed — see README and `.env.example`). Native map
/// rendering additionally needs the key wired per platform:
/// - Android: `manifestPlaceholders["MAPS_API_KEY"]` → AndroidManifest meta-data
/// - iOS: `GMSServices.provideAPIKey` from the `MapsApiKey` Info.plist entry
/// - Web: the Maps JS `<script>` in `web/index.html`
///
/// When [isConfigured] is false the UI hides map entry points and falls back to
/// the existing distance-sorted list, so builds and runtime stay safe without a
/// key.
class MapsConfig {
  const MapsConfig._();

  /// Google Maps Platform API key, supplied at build time. Empty when unset.
  static const String apiKey =
      String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

  /// Whether a non-empty Maps API key was provided at build time.
  static bool get isConfigured => apiKey.isNotEmpty;
}
