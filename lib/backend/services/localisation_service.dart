/// Reads [users.language_preference] and exposes locale (wire to SQLite in a later step).
final class LocalisationService {
  LocalisationService();

  String languageCode = 'en';

  void setLanguage(String code) {
    languageCode = code;
  }
}
