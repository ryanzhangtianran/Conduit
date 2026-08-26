import 'package:easy_localization/easy_localization.dart';

/// Localized compact relative time label ("just now", "37s ago", "5m ago", …).
///
/// Shared by the server dashboard and the GitHub surfaces so both read the
/// same way in every language. The seconds tier matters for metrics that
/// refresh on a seconds-scale interval; coarser callers simply never hit it.
String relativeTimeLabel(DateTime time) {
  final delta = DateTime.now().difference(time);
  if (delta.inSeconds < 15) return 'agentJustNow'.tr();
  if (delta.inMinutes < 1) {
    return 'agentSecondsAgo'.tr(args: ['${delta.inSeconds}']);
  }
  if (delta.inHours < 1) {
    return 'agentMinutesAgo'.tr(args: ['${delta.inMinutes}']);
  }
  if (delta.inDays < 1) {
    return 'agentHoursAgo'.tr(args: ['${delta.inHours}']);
  }
  return 'agentDaysAgo'.tr(args: ['${delta.inDays}']);
}
