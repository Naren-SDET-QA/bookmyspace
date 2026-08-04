class AuthCallbackError {
  const AuthCallbackError({required this.code, required this.description});

  final String code;
  final String description;

  bool get isExpired =>
      code == 'otp_expired' ||
      (code == 'access_denied' &&
          description.toLowerCase().contains('expired'));
}

AuthCallbackError? authCallbackErrorFromUri(Uri uri) {
  final parameters = <String, String>{...uri.queryParameters};
  final fragment = uri.fragment;
  final queryStart = fragment.indexOf('?');
  final fragmentQuery = queryStart >= 0
      ? fragment.substring(queryStart + 1)
      : (fragment.contains('=') ? fragment : '');
  if (fragmentQuery.isNotEmpty) {
    parameters.addAll(Uri.splitQueryString(fragmentQuery));
  }
  final code = parameters['error_code'] ?? parameters['error'];
  if (code == null) return null;
  return AuthCallbackError(
    code: code,
    description:
        parameters['error_description'] ?? 'Email confirmation failed.',
  );
}

bool isAuthCallbackUri(Uri uri) {
  if (authCallbackErrorFromUri(uri) != null) return true;
  if (uri.queryParameters.containsKey('code') ||
      uri.queryParameters['auth_callback'] == '1') {
    return true;
  }
  return uri.fragment.startsWith('/auth/callback');
}
