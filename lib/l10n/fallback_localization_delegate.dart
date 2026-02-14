import 'package:flutter/widgets.dart';

class FallbackLocalizationDelegate<T> extends LocalizationsDelegate<T> {
  const FallbackLocalizationDelegate(this._baseDelegate, {Locale? fallback})
    : _fallbackLocale = fallback ?? const Locale('en');

  final LocalizationsDelegate<T> _baseDelegate;
  final Locale _fallbackLocale;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) {
    final resolvedLocale = _baseDelegate.isSupported(locale)
        ? locale
        : Locale(_fallbackLocale.languageCode, _fallbackLocale.countryCode);
    return _baseDelegate.load(resolvedLocale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}
