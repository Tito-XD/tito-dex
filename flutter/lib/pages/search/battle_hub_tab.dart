import 'package:flutter/material.dart';

import '../../models/journey.dart';
import '../../widgets/companion_tools_panel.dart';

/// v0.4.0: §7.4 battle hub — companion tools relocated from search tab.
class BattleHubTab extends StatelessWidget {
  const BattleHubTab({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return CompanionToolsPanel(journey: journey);
  }
}
