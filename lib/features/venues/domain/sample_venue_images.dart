/// Deterministic, public Unsplash imagery for DEV/sample listings only.
/// Real venue image rows always take precedence in [Venue.coverImageUrl].
class SampleVenueImages {
  const SampleVenueImages._();

  static const _sets = <String, List<String>>{
    'hotel': [
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1551882547-ff40c63ea294?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1445019980177-7f33d48bd99d?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1611892440504-42a792e24d32?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=1200&auto=format&fit=crop&q=82',
    ],
    'resort': [
      'https://images.unsplash.com/photo-1582610116397-edb318620f90?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1540541338287-41700207dee6?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200&auto=format&fit=crop&q=82',
    ],
    'pg': [
      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=1200&auto=format&fit=crop&q=82',
    ],
    'institute': [
      'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1509062522246-3755977927d7?w=1200&auto=format&fit=crop&q=82',
    ],
    'sports': [
      'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=1200&auto=format&fit=crop&q=82',
    ],
    'function': [
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1511578314322-379afb476865?w=1200&auto=format&fit=crop&q=82',
    ],
    'event': [
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=1200&auto=format&fit=crop&q=82',
      'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1200&auto=format&fit=crop&q=82',
    ],
    'generic': [
      'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200&auto=format&fit=crop&q=82',
    ],
  };

  static const _androidSets = <String, List<String>>{
    'function': [
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1527529482837-4698179dc6ce?auto=format&fit=crop&w=800&q=80',
    ],
    'hotel': [
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=800&q=80',
    ],
    'pg': [
      'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80',
    ],
    'meeting': [
      'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1517502884422-41eaead166d4?auto=format&fit=crop&w=800&q=80',
    ],
    'sports': [
      'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=800&q=80',
    ],
  };

  static List<String> androidGalleryForCategory(String categorySlug) {
    final slug = categorySlug.toLowerCase();
    final key = slug.contains('sport') || slug.contains('turf')
        ? 'sports'
        : slug.contains('meeting') || slug.contains('conference')
        ? 'meeting'
        : slug.contains('pg') ||
              slug.contains('hostel') ||
              slug.contains('living')
        ? 'pg'
        : slug.contains('hotel') ||
              slug.contains('stay') ||
              slug.contains('resort')
        ? 'hotel'
        : slug.contains('hall') ||
              slug.contains('function') ||
              slug.contains('wedding')
        ? 'function'
        : 'function';
    return _androidSets[key]!;
  }

  static String forVenue({required String id, String categorySlug = ''}) {
    final slug = categorySlug.toLowerCase();
    final key = slug.contains('sport')
        ? 'sports'
        : slug.contains('hotel') ||
              slug.contains('lodge') ||
              slug.contains('room') ||
              slug.contains('stay')
        ? 'hotel'
        : slug.contains('resort') || slug.contains('home')
        ? 'resort'
        : slug.contains('pg') ||
              slug.contains('hostel') ||
              slug.contains('living')
        ? 'pg'
        : slug.contains('institute') ||
              slug.contains('class') ||
              slug.contains('academy') ||
              slug.contains('coaching')
        ? 'institute'
        : slug.contains('event') || slug.contains('concert')
        ? 'event'
        : slug.contains('hall') ||
              slug.contains('venue') ||
              slug.contains('auditorium')
        ? 'function'
        : 'generic';
    final images = _sets[key]!;
    final hash = id.codeUnits.fold<int>(0, (value, unit) => value * 31 + unit);
    return images[hash.abs() % images.length];
  }

  /// Shared DEV seed URLs that were applied to every category. They are not
  /// owner uploads, so [Venue.coverImageUrl] should ignore them and pick a
  /// category-specific sample instead.
  static bool isSharedDevFixture(String url) {
    return url.contains('photo-1519167758481') ||
        url.contains('photo-1497366811353');
  }

  static bool isAndroidGenericFallback(String url) =>
      url ==
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=800&q=80';
}
