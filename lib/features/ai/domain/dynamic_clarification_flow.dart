import 'dynamic_clarification.dart';
import '../../venues/domain/category_configuration.dart';

enum ClarificationResultStatus {
  ready,
  missingFields,
  categoryNotFound,
  categoryClarificationRequired,
  invalidField,
  expired,
  featureDisabled,
}

class ClarificationResult {
  const ClarificationResult({required this.status, this.state, this.category, this.missingFields = const [], this.message});
  final ClarificationResultStatus status;
  final ClarificationState? state;
  final CategoryConfiguration? category;
  final List<DynamicField> missingFields;
  final String? message;
}

/// Generic, configuration-driven clarification coordinator. It deliberately
/// knows no category slugs; category aliases and fields come from metadata.
class DynamicClarificationFlow {
  DynamicClarificationFlow(this.categories, {this.now});

  final List<CategoryConfiguration> categories;
  final DateTime Function()? now;

  ClarificationResult start(String request, {String userId = 'anonymous', String sessionId = 'local-session'}) {
    final normalizedRequest = request.toLowerCase().replaceAll('_', ' ');
    final matches = categories.where((category) => category.visible && category.searchable && category.allAliases.any((alias) => normalizedRequest.contains(alias.toLowerCase().replaceAll('_', ' ')))).toList();
    if (matches.isEmpty) return const ClarificationResult(status: ClarificationResultStatus.categoryNotFound);
    if (matches.map((item) => item.id).toSet().length > 1) return const ClarificationResult(status: ClarificationResultStatus.categoryClarificationRequired);
    final category = matches.first;
    if (!category.bookable) return ClarificationResult(status: ClarificationResultStatus.featureDisabled, category: category);
    final schema = _schema(category);
    final state = ClarificationState.create(userId: userId, sessionId: sessionId, categorySlug: category.slug, requiredFields: schema.requiredKeys, now: (now ?? DateTime.now)());
    return _result(state, category, schema);
  }

  ClarificationState answer(ClarificationState state, String key, Object? value, {DynamicFieldSchema? schema}) {
    state.forUser(state.userId);
    final activeSchema = schema ?? DynamicFieldSchema(const []);
    final field = activeSchema.fields.where((item) => item.key == key).firstOrNull;
    if (field != null && field.options.isNotEmpty && value != null && !field.options.contains(value.toString())) throw FormatException('Invalid option for $key');
    final answered = value == null ? state.removeAnswer(key) : state.answer(key, value);
    final required = {
      ...answered.requiredFields,
      ...activeSchema.fields.where((item) => item.required && _active(item, answered.values)).map((item) => item.key),
    }.toList();
    return answered.withRequiredFields(required);
  }

  void validateOption(String value, List<String> options) {
    if (!options.contains(value)) throw const FormatException('Invalid option');
  }

  ClarificationResult continueWith(ClarificationState state, CategoryConfiguration category, DynamicFieldSchema schema) {
    try { state.forUser(state.userId); } on StateError catch (error) { return ClarificationResult(status: ClarificationResultStatus.expired, category: category, message: error.message); }
    return _result(state, category, schema);
  }

  DynamicFieldSchema _schema(CategoryConfiguration category) => DynamicFieldSchema.fromMetadata({'fields': [
    ...category.requiredFields.map((key) => {'key': key, 'label': key, 'required': true}),
    ...category.optionalFields.map((key) => {'key': key, 'label': key}),
  ]});

  ClarificationResult _result(ClarificationState state, CategoryConfiguration category, DynamicFieldSchema schema) {
    final missing = schema.fields.where((field) => _active(field, state.values) && field.required && _empty(state.values[field.key])).toList(growable: false);
    return ClarificationResult(status: missing.isEmpty ? ClarificationResultStatus.ready : ClarificationResultStatus.missingFields, state: state, category: category, missingFields: missing);
  }

  bool _active(DynamicField field, Map<String, dynamic> values) {
    final when = field.validation['when'];
    if (when is! Map) return true;
    final key = when['field']?.toString();
    return key == null || values[key]?.toString() == when['equals']?.toString();
  }

  bool _empty(Object? value) => value == null || (value is String && value.trim().isEmpty);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
