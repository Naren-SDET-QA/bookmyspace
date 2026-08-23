import 'package:speech_to_text/speech_to_text.dart';

import '../../features/payments/domain/checkout_service.dart';
import '../../features/payments/presentation/checkout_service_factory.dart';
import 'plugin_kind.dart';
import 'plugins/flutter_map_plugin.dart';
import 'plugins/map_provider.dart';
import 'plugins/payment_checkout_plugin.dart';
import 'plugins/speech_voice_plugin.dart';
import 'plugins/voice_provider.dart';
import 'provider_registry.dart';

/// Registers the real checkout, map, and speech factories. Factories are not
/// invoked until [ProviderRegistry.resolve].
void registerDefaultPlugins(
  ProviderRegistry registry, {
  CheckoutService Function()? checkoutFactory,
  SpeechToText Function()? speechFactory,
  MapProvider Function()? mapFactory,
  VoiceProvider Function()? voiceFactory,
}) {
  registry.register(
    PluginKind.payment,
    () => PaymentCheckoutPlugin(checkoutFactory ?? createCheckoutService),
  );
  registry.register(PluginKind.map, mapFactory ?? FlutterMapPlugin.new);
  registry.register(
    PluginKind.voice,
    voiceFactory ?? () => SpeechVoicePlugin(create: speechFactory),
  );
}
