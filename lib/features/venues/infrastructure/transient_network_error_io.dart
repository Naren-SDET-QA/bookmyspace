import 'dart:io';

/// Native (Android/iOS/desktop) check for a transient, retry-worthy network
/// failure. Mirrors the previous inline `error is SocketException` check
/// that lived directly in [SupabaseMediaRepository] before it was extracted
/// so the repository could also build for Web (which has no `dart:io`).
bool isTransientNetworkError(Object error) => error is SocketException;
