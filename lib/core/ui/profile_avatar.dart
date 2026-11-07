import 'package:flutter/material.dart';

import '../../app/theme/palier_accent.dart';
import '../../app/theme/palier_theme.dart';
import '../../features/profiles/domain/profile.dart';

/// Pastille d'un profil : son initiale sur sa couleur.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.size = 48});

  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: profile.accent.color, shape: BoxShape.circle),
        child: Text(
          profile.initial,
          style: TextStyle(
            fontFamily: PalierFonts.display,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.42,
            height: 1,
            color: PalierAccent.onAccent,
          ),
        ),
      ),
    );
  }
}
