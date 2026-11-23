/// PillPaatha speaks ONE language at a time (Guna's design rule,
/// 23 Nov 2026): the whole UI — every label, button, banner and
/// notification — is either Tamil or English, never a bilingual mix.
/// The user switches with one tap in the AppBar; the choice persists.
///
/// Content that exists in both languages (medicine explanations,
/// caution notes, status names) is stored bilingually in the models
/// and the UI picks exactly one via [AppLanguage.pick].
library;

enum AppLanguage {
  en,
  ta;

  bool get isTamil => this == AppLanguage.ta;

  /// Returns [ta] when the current language is Tamil, else [en].
  String pick(String en, String ta) => isTamil ? ta : en;

  /// This language's name in its own script. The AppBar toggle
  /// shows the OTHER language's [ownName], so the button is
  /// findable whichever language is currently on screen.
  String get ownName => this == AppLanguage.en ? 'EN' : 'தமிழ்';

  AppLanguage get other =>
      this == AppLanguage.en ? AppLanguage.ta : AppLanguage.en;

  static AppLanguage fromName(String? name) =>
      AppLanguage.values.where((l) => l.name == name).firstOrNull ??
      AppLanguage.ta;
}
