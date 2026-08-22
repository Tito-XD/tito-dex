class JourneyWorkerConfig {
  const JourneyWorkerConfig._();

  static const askUrl = String.fromEnvironment('TITODEX_JOURNEY_ASSISTANT_URL');
  static const askPath = '/v1/ask';
  static const packCatalogPath = '/v1/journey-packs/catalog';

  static Uri? askUri([String value = askUrl]) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.path != askPath ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }

  static Uri? packCatalogUri([String value = askUrl]) =>
      askUri(value)?.replace(path: packCatalogPath);
}
