import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/app/routes.dart';
import 'package:palier/app/theme/palier_accent.dart';
import 'package:palier/features/profiles/domain/profile.dart';

Profile _profile(String id, {bool hasPin = false, bool expenses = true, bool sport = true}) => Profile(
  id: id,
  name: id,
  accent: PalierAccent.cyan,
  currency: PalierCurrency.xof,
  isMinor: false,
  expensesEnabled: expenses,
  sportEnabled: sport,
  hasPin: hasPin,
  biometricEnabled: false,
  createdAt: DateTime.utc(2026, 11, 7),
);

String? _go(String location, {List<Profile>? profiles, Session session = const Session()}) => resolveRedirect(
  profiles: profiles == null ? const AsyncLoading() : AsyncData(profiles),
  session: session,
  location: location,
);

void main() {
  test('attend la base sur l’écran de chargement', () {
    expect(_go(Routes.home), Routes.loading);
    expect(_go(Routes.loading), isNull);
  });

  test('sans profil, accueille et propose d’en créer un', () {
    expect(_go(Routes.loading, profiles: []), Routes.welcome);
    expect(_go(Routes.picker, profiles: []), Routes.welcome);
    expect(_go(Routes.welcome, profiles: []), isNull);
    expect(_go(Routes.welcomeProfile, profiles: []), isNull);
  });

  test('sans profil ouvert, demande qui est là', () {
    final profiles = [_profile('ama'), _profile('kofi')];

    expect(_go(Routes.home, profiles: profiles), Routes.picker);
    expect(_go(Routes.settings, profiles: profiles), Routes.picker);
    expect(_go(Routes.picker, profiles: profiles), isNull);
    expect(_go(Routes.pickerNew, profiles: profiles), isNull);
    expect(_go(Routes.unlock('ama'), profiles: profiles), isNull);
  });

  test('après un verrouillage, redemande directement le code du dernier profil', () {
    final profiles = [_profile('ama', hasPin: true), _profile('kofi')];

    expect(
      _go(
        Routes.home,
        profiles: profiles,
        session: const Session(lastProfileId: 'ama'),
      ),
      Routes.unlock('ama'),
    );
    expect(
      _go(
        Routes.home,
        profiles: profiles,
        session: const Session(lastProfileId: 'kofi'),
      ),
      Routes.picker,
    );
  });

  test('un profil ouvert ne revoit ni l’accueil, ni le choix, ni le chargement', () {
    final profiles = [_profile('ama')];
    const session = Session(activeProfileId: 'ama');

    for (final location in [Routes.loading, Routes.welcome, Routes.picker, Routes.unlock('ama')]) {
      expect(
        _go(location, profiles: profiles, session: session),
        Routes.home,
        reason: location,
      );
    }
    expect(_go(Routes.settingsBackup, profiles: profiles, session: session), isNull);
  });

  test('un module désactivé n’est pas accessible', () {
    final profiles = [_profile('ama', expenses: false, sport: false)];
    const session = Session(activeProfileId: 'ama');

    expect(_go(Routes.expenses, profiles: profiles, session: session), Routes.home);
    expect(_go(Routes.sport, profiles: profiles, session: session), Routes.home);
    expect(_go(Routes.home, profiles: profiles, session: session), isNull);
  });

  test('un profil supprimé pendant qu’il était ouvert renvoie au choix', () {
    expect(
      _go(
        Routes.home,
        profiles: [_profile('kofi')],
        session: const Session(activeProfileId: 'ama'),
      ),
      Routes.picker,
    );
  });
}
