import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legebre/l10n/app_localizations.dart';
import 'package:legebre/screens/add_listing_screen.dart';

void main() {
  testWidgets('AddListingScreen builds without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AddListingScreen(),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Share accurate info'), findsOneWidget);
  });
}
