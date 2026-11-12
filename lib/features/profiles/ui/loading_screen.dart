import 'package:material_ui/material_ui.dart';

import '../../../app/theme/palier_tokens.dart';
import '../../../core/ui/palier_mark.dart';

/// Le temps d'ouvrir la base, au démarrage.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: PalierColors.deep,
      body: Center(child: PalierMark(height: 72)),
    );
  }
}
