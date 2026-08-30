import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../features/notifications/domain/device_token_repository.dart';
import '../config/app_config.dart';
import '../router/app_router.dart';
import 'push_channels.dart';
import 'push_route_resolver.dart';

/// Handles OneSignal push notification registration, permission requests,
/// and foreground/background/terminated message handling.
///
/// Replaces the previous direct FCM implementation. Preserves the parts of
/// that implementation the notification architecture depends on:
///  - the same server pipeline (`notifications` -> `push_outbox` ->
///    `send-push-outbox`), which now calls OneSignal's Create Notification
///    API instead of FCM HTTP v1 -- see
///    `supabase/functions/_shared/onesignal.ts`;
///  - the same [DeviceTokenRepository] contract, so `public.device_tokens`
///    keeps a local, RLS-protected record of this device's registration
///    for observability. The `token` column now holds this device's
///    OneSignal push-subscription id instead of an FCM registration token;
///  - the same [PushRouteResolver]-driven notification-tap routing and
///    [PushChannels] Android channel taxonomy, applied to foreground
///    messages exactly as before (see the class doc on [init] for why
///    foreground display is still handled locally rather than left to
///    OneSignal's own default display).
///
/// Every public method is fully defensive: it is a no-op whenever
/// [AppConfig.oneSignalAppId] is empty (no
/// `--dart-define=ONESIGNAL_APP_ID=...` supplied -- e.g. in this dev
/// environment, or in `flutter test`, which never calls
/// `OneSignal.initialize`). This means importing and calling this service
/// can never crash the app or break existing widget tests, even though
/// push notifications will not actually be delivered until a real
/// OneSignal App ID is configured.
class OneSignalPushService {
  OneSignalPushService._();

  static final OneSignalPushService instance = OneSignalPushService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get _ready => AppConfig.oneSignalAppId.isNotEmpty;

  DeviceTokenRepository? _tokenRepository;

  // Kept as a field (rather than a closure created inline) so the exact
  // same callback reference can be passed to removeObserver in
  // onSignedOut -- OneSignal's addObserver/removeObserver pair matches by
  // reference, not by subscription handle.
  void Function(OSPushSubscriptionChangedState state)? _subscriptionObserver;

  /// Call once at startup, before a user is necessarily signed in.
  /// Initializes the OneSignal SDK and wires the foreground-display and
  /// notification-click listeners. Does NOT request permission or
  /// associate a user with this device -- that happens in [onSignedIn],
  /// matching the previous FCM implementation's ordering (permission is
  /// only requested once someone is actually signed in).
  ///
  /// Foreground messages are intentionally displayed via
  /// [FlutterLocalNotificationsPlugin] on our own [PushChannels], the same
  /// as the previous FCM implementation, rather than left to OneSignal's
  /// default foreground display. OneSignal's own display only picks a
  /// per-type Android channel when the server payload's
  /// `android_channel_id` is configured against a channel created in the
  /// OneSignal dashboard; reproducing that mapping in code alone is not
  /// possible, so background/terminated notifications (which OneSignal
  /// always displays natively) fall back to OneSignal's default channel
  /// until that dashboard configuration is added -- see the production
  /// setup notes for this task.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!_ready) {
      debugPrint(
        'OneSignalPushService: ONESIGNAL_APP_ID not configured, push disabled.',
      );
      return;
    }
    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      }
      OneSignal.initialize(AppConfig.oneSignalAppId);
      await _initLocalNotifications();

      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        // Suppress OneSignal's own display and show our own local
        // notification instead, so foreground pushes keep using
        // PushChannels/PushRouteResolver exactly as before.
        event.preventDefault();
        _showLocalNotification(event.notification);
      });

      OneSignal.Notifications.addClickListener((event) {
        _navigateTo(
          PushRouteResolver.resolve(
            event.notification.additionalData ?? const <String, dynamic>{},
          ),
        );
      });
    } catch (e) {
      debugPrint('OneSignalPushService.init failed: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _navigateTo(route);
      },
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channel in PushChannels.all) {
      await androidPlugin?.createNotificationChannel(channel);
    }
    await androidPlugin?.requestNotificationsPermission();
  }

  void _showLocalNotification(OSNotification notification) {
    final data = notification.additionalData ?? const <String, dynamic>{};
    final title = notification.title ?? 'BookMySpace';
    final body = notification.body ?? '';
    final channelId = PushChannels.channelIdForType(
      data['notification_type'] ?? data['type'],
    );
    final route = PushRouteResolver.resolve(data);
    unawaited(
      _localNotifications.show(
        notification.notificationId.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            PushChannels.nameFor(channelId),
            channelDescription: PushChannels.descriptionFor(channelId),
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: route,
      ),
    );
  }

  void _navigateTo(String route) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    try {
      // Shell destinations (e.g. /bookings) must use go, not push, or a
      // second stack is created and query params like highlight= are dropped.
      GoRouter.of(context).go(route);
    } catch (e) {
      debugPrint('OneSignalPushService navigation failed: $e');
    }
  }

  /// Requests notification permission, associates this device with
  /// [userId] via OneSignal's External ID (`OneSignal.login`) so server
  /// sends can target `include_aliases.external_id: [userId]`, and
  /// registers the resulting push-subscription id against [userId] in our
  /// own `device_tokens` table via [repository] for observability. Also
  /// observes subscription-id changes (OneSignal's equivalent of FCM token
  /// refresh) so a rotated subscription id stays registered. Called on
  /// sign-in with the just-authenticated user's id.
  Future<void> onSignedIn(DeviceTokenRepository repository, String userId) async {
    _tokenRepository = repository;
    if (!_ready || userId.isEmpty) return;
    try {
      await OneSignal.Notifications.requestPermission(true);

      // Associates this device's push subscription(s) with our own user id
      // on OneSignal's backend. This -- not local bookkeeping -- is what
      // send-push-outbox actually targets, and what prevents a previous
      // account's pushes from continuing to arrive after a different user
      // signs in on the same device (see onSignedOut for the logout half).
      OneSignal.login(userId);

      final currentId = OneSignal.User.pushSubscription.id;
      if (currentId != null && currentId.isNotEmpty) {
        await repository.registerToken(
          token: currentId,
          platform: _platformName(),
        );
      }

      _removeSubscriptionObserver();
      _subscriptionObserver = (state) {
        final id = state.current.id;
        if (id != null && id.isNotEmpty) {
          unawaited(
            repository.registerToken(token: id, platform: _platformName()),
          );
        }
      };
      OneSignal.User.pushSubscription.addObserver(_subscriptionObserver!);
    } catch (e) {
      debugPrint('OneSignalPushService.onSignedIn failed: $e');
    }
  }

  /// Deregisters this device's OneSignal subscription id and logs the
  /// device out of OneSignal's External ID association. Called on
  /// sign-out (while the Supabase session is still valid, so RLS still
  /// permits deleting the `device_tokens` row) so a shared device does not
  /// keep receiving push notifications for the previous account.
  ///
  /// `OneSignal.logout()` is the critical call here: without it, this
  /// device stays associated with the signed-out user's external id on
  /// OneSignal's backend and would keep receiving their pushes even after
  /// a different user signs in, since login()/logout() -- not our local
  /// device_tokens table -- is the source of truth OneSignal's send API
  /// targets.
  Future<void> onSignedOut() async {
    final repository = _tokenRepository;
    try {
      if (_ready && repository != null) {
        final id = OneSignal.User.pushSubscription.id;
        if (id != null && id.isNotEmpty) await repository.deregisterToken(id);
      }
      if (_ready) OneSignal.logout();
    } catch (e) {
      debugPrint('OneSignalPushService.onSignedOut failed: $e');
    } finally {
      _removeSubscriptionObserver();
      _tokenRepository = null;
    }
  }

  void _removeSubscriptionObserver() {
    final observer = _subscriptionObserver;
    if (observer != null && _ready) {
      OneSignal.User.pushSubscription.removeObserver(observer);
    }
    _subscriptionObserver = null;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
