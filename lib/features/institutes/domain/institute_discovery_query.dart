import 'institute_profile.dart';

/// Client-side discovery filter over published institute rows from Supabase.
class InstituteDiscoveryQuery {
  const InstituteDiscoveryQuery({this.query = '', this.verifiedOnly = false});

  final String query;
  final bool verifiedOnly;

  List<InstituteProfile> apply(List<InstituteProfile> institutes) {
    final needle = query.trim().toLowerCase();
    return institutes.where((institute) {
      if (verifiedOnly && !institute.isVerified) return false;
      if (needle.isEmpty) return true;
      return [
        institute.name,
        institute.description,
        institute.city,
        institute.address,
        institute.state,
      ].any((value) => value.toLowerCase().contains(needle));
    }).toList();
  }
}
