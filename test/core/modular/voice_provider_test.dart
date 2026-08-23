import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/modular/plugin_kind.dart';
import 'package:bookmyspace/core/modular/plugins/speech_voice_plugin.dart';
import 'package:bookmyspace/core/modular/plugins/voice_provider.dart';
import 'package:bookmyspace/core/modular/provider_registry.dart';
import 'package:bookmyspace/core/modular/register_default_plugins.dart';
import 'package:bookmyspace/features/ai/domain/booking_intent.dart';
import 'package:bookmyspace/features/ai/domain/voice_locale.dart';
import 'package:bookmyspace/features/ai/presentation/voice_booking_sheet.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/venues/mock_venue_repository.dart';

class _RecordingVoiceProvider implements VoiceProvider {
  bool _ready = false;

  @override
  String get id => 'fake_voice';

  @override
  bool get initialized => _ready;

  @override
  Future<void> ensureInitialized() async => _ready = true;

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words) onResult,
  }) async {
    onResult('function hall in Hyderabad');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => _ready = false;
}

void main() {
  setUp(FeatureRegistry.reset);
  tearDown(FeatureRegistry.reset);

  test('voice plugin is cached and SpeechToText stays lazy until init', () async {
    var pluginBuilt = 0;
    var speechBuilt = 0;
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(
      plugins,
      voiceFactory: () {
        pluginBuilt++;
        return SpeechVoicePlugin(
          create: () {
            speechBuilt++;
            throw StateError('SpeechToText should stay lazy');
          },
        );
      },
    );

    expect(pluginBuilt, 0);
    expect(speechBuilt, 0);
    expect(plugins.isInitialized(PluginKind.voice), isFalse);

    final first = plugins.resolve(PluginKind.voice);
    expect(pluginBuilt, 1);
    expect(speechBuilt, 0);
    expect(first, isA<VoiceProvider>());
    expect(plugins.resolve(PluginKind.voice), same(first));
    expect(pluginBuilt, 1);
    expect(plugins.isInitialized(PluginKind.voice), isFalse);

    await expectLater(
      (first as VoiceProvider).ensureInitialized(),
      throwsA(isA<StateError>()),
    );
    expect(speechBuilt, 1);
  });

  test('disabled voice never constructs the provider or SpeechToText', () {
    var pluginBuilt = 0;
    var speechBuilt = 0;
    final features = FeatureRegistry.defaults()
      ..apply(FeatureId.voice, enabled: false);
    final plugins = ProviderRegistry(features: features);
    registerDefaultPlugins(
      plugins,
      voiceFactory: () {
        pluginBuilt++;
        return SpeechVoicePlugin(
          create: () {
            speechBuilt++;
            throw StateError('SpeechToText must not be constructed');
          },
        );
      },
    );

    expect(plugins.tryResolve(PluginKind.voice), isNull);
    expect(pluginBuilt, 0);
    expect(speechBuilt, 0);
  });

  test('voice provider can be replaced', () async {
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(plugins);
    final first = plugins.resolve(PluginKind.voice);
    expect(first.id, 'speech_to_text');

    await plugins.replace(PluginKind.voice, _RecordingVoiceProvider.new);
    final second = plugins.resolve(PluginKind.voice);
    expect(second, isA<_RecordingVoiceProvider>());
    expect(second.id, 'fake_voice');
    expect(identical(first, second), isFalse);
  });

  test('voice locales stay te_IN, hi_IN and en_IN', () {
    expect(VoiceLocale.speechId(const Locale('en')), 'en_IN');
    expect(VoiceLocale.speechId(const Locale('te')), 'te_IN');
    expect(VoiceLocale.speechId(const Locale('hi')), 'hi_IN');
    expect(VoiceLocale.speechId(const Locale('fr')), 'en_IN');
  });

  testWidgets('typed fallback works when voice is disabled', (tester) async {
    FeatureRegistry.configure(FeatureId.voice, enabled: false);
    BookingIntent? confirmed;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: VoiceBookingSheet(onConfirmed: (intent) => confirmed = intent),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none), findsNothing);
    expect(find.byIcon(Icons.mic), findsNothing);
    await tester.enterText(
      find.byType(TextField),
      'I need a function hall in Hyderabad for 200 people under 30,000',
    );
    await tester.tap(find.text('Interpret request'));
    await tester.pump();
    expect(
      find.text('function_halls · Hyderabad · 200 guests · budget 30000.0'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm and search'));
    await tester.pump();
    expect(confirmed?.category, 'function_halls');
    expect(confirmed?.location, 'Hyderabad');
  });

  testWidgets('default voice keeps microphone and typed search', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
        ],
        child: const MaterialApp(
          home: SearchScreen(initialSection: 'function_halls'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Voice search'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
  });
}
