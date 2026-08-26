import 'package:conduit/data/local/app_database.dart';

/// The address line shown next to a server's name.
String serverAddressLabel(Server server) =>
    '${server.username}@${server.host}:${server.port}';
