/// Web build of the transient-network-error check.
///
/// `dart:io`'s `SocketException` does not exist on Web, so there is no
/// direct equivalent to check here. Returning `false` is behavior-preserving:
/// this file only exists because the Web target could not previously compile
/// this repository at all, so there is no prior Web behavior to match. Other
/// transient-failure detection (the storage-related text match already in
/// [SupabaseMediaRepository]) still applies unchanged on Web.
bool isTransientNetworkError(Object error) => false;
