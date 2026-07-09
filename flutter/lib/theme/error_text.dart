import '../features/dex/pokeapi_client.dart';
import '../l10n/app_zh.dart';

/// User-facing error copy — never show raw exception strings in UI.
String formatUserFacingError(Object error) {
  if (error is PokeApiException) {
    return AppZh.dexLoadFailedDetail(error.statusCode);
  }
  if (error is FormatException) {
    return AppZh.errorFormatDetail;
  }
  return AppZh.errorGeneric;
}

/// Title + detail for sticker-card error panels.
(String title, String detail) splitUserFacingError(Object error) {
  if (error is PokeApiException) {
    return (AppZh.dexLoadFailed, AppZh.dexLoadFailedDetail(error.statusCode));
  }
  if (error is FormatException) {
    return (AppZh.dexLoadFailed, AppZh.errorFormatDetail);
  }
  return (AppZh.dexLoadFailed, AppZh.errorGeneric);
}
