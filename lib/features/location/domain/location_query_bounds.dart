/// Caps location queries so Flutter never loads the full India master.
class LocationQueryBounds {
  const LocationQueryBounds._();

  static const int childrenPageSize = 50;
  static const int searchPageSize = 25;
  static const int pinPageSize = 50;

  static int clamp(int requested, {required int cap}) {
    if (requested < 1) return 1;
    return requested > cap ? cap : requested;
  }
}
