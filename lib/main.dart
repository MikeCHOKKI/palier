import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/palier_app.dart';
import 'app/providers.dart';
import 'data/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  _registerFontLicenses();

  runApp(
    ProviderScope(overrides: [databaseProvider.overrideWithValue(PalierDatabase.device())], child: const PalierApp()),
  );
}

/// Les polices embarquées sont sous licence OFL : on l'affiche dans « Licences ».
void _registerFontLicenses() {
  for (final (font, file) in [('Unbounded', 'OFL-Unbounded.txt'), ('Manrope', 'OFL-Manrope.txt')]) {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/licenses/$file');
      yield LicenseEntryWithLineBreaks([font], text);
    });
  }
}
