// Adapted from Solian's island_ui_foundation package (AGPL-3.0),
// https://src.solsynth.dev/SoSYS/Solian — vendored so Conduit has no
// build-time dependency on that repository.

import 'package:flutter/widgets.dart';

const kWideScreenWidth = 768.0;
const kWiderScreenWidth = 1024.0;
const kWidescreenWidth = 1280.0;

bool isWideScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width > kWideScreenWidth;
}

bool isWiderScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width > kWiderScreenWidth;
}

bool isWidestScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width > kWidescreenWidth;
}
