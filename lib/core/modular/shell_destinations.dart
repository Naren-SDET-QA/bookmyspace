import 'feature_id.dart';
import 'feature_registry.dart';

/// One bottom-nav item. [feature] is null for destinations that always stay.
class ShellDestination {
  const ShellDestination({
    required this.branchIndex,
    required this.id,
    this.feature,
  });

  final int branchIndex;
  final String id;
  final FeatureId? feature;
}

const shellDestinationCatalog = [
  ShellDestination(branchIndex: 0, id: 'home'),
  ShellDestination(
    branchIndex: 1,
    id: 'notifications',
    feature: FeatureId.notifications,
  ),
  ShellDestination(branchIndex: 2, id: 'search', feature: FeatureId.search),
  ShellDestination(branchIndex: 3, id: 'bookings', feature: FeatureId.booking),
  ShellDestination(branchIndex: 4, id: 'courses', feature: FeatureId.courses),
  ShellDestination(branchIndex: 5, id: 'profile'),
];

List<ShellDestination> visibleShellDestinations(FeatureRegistry registry) {
  return shellDestinationCatalog
      .where(
        (item) =>
            item.feature == null ||
            (registry.isExposed(item.feature!) &&
                (registry.configOf(item.feature!).config['navigation_visible']
                        as bool? ??
                    true)),
      )
      .toList(growable: false);
}

int selectedShellIndex({
  required int currentBranch,
  required List<ShellDestination> visible,
}) {
  final index = visible.indexWhere((item) => item.branchIndex == currentBranch);
  return index < 0 ? 0 : index;
}
