import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'github_section.dart';

/// GitHub connections, pinned repositories and workflow runs as a top-level
/// sidebar page. Sign-in and pin controls live inside the section, so no FAB.
@RoutePage()
class GithubPage extends StatelessWidget {
  const GithubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConduitAppScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: const [GitHubSection(showHeader: false)],
      ),
    );
  }
}
