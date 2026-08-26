import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/server_connection_actions.dart';

void main() {
  test('names the private key when key authentication was used', () {
    expect(
      sshAuthFailureMessage(
        credentialType: CredentialType.privateKey,
        serverAuthMethods: 'publickey, password',
      ),
      'Conduit offered the private key and the server rejected it. '
      'The server accepts: publickey, password. '
      'Check that the matching public key is in authorized_keys for this user '
      'and that the home and .ssh directories are not group-writable.',
    );
  });

  test('names the password when password authentication was used', () {
    expect(
      sshAuthFailureMessage(
        credentialType: CredentialType.password,
        serverAuthMethods: 'publickey,password',
      ),
      'Conduit offered the password and the server rejected it. '
      'The server accepts: publickey, password. '
      'This server also accepts public keys; switch the credential to a '
      'private key if password logins are restricted.',
    );
  });

  test('omits the method list when the server advertised none', () {
    expect(
      sshAuthFailureMessage(credentialType: CredentialType.password),
      'Conduit offered the password and the server rejected it.',
    );
  });

  test('points out a server that does not offer public key auth', () {
    expect(
      sshAuthFailureMessage(
        credentialType: CredentialType.privateKey,
        serverAuthMethods: 'keyboard-interactive',
      ),
      'Conduit offered the private key and the server rejected it. '
      'The server accepts: keyboard-interactive. '
      'This server does not offer public key authentication.',
    );
  });
}
