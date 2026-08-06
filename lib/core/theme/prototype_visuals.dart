import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Visual tokens and helpers mirroring `prototype/bookmyspace-app.html`.
abstract final class PrototypeVisuals {
  PrototypeVisuals._();

  static const Color badgeVenueBg = Color(0xFFEFE9FF);
  static const Color badgeClassBg = Color(0xFFE0EDFF);
  static const Color badgeClassFg = Color(0xFF1D4ED8);
  static const Color badgeEventBg = Color(0xFFD9F7EF);
  static const Color badgeEventFg = Color(0xFF0F766E);
  static const Color badgeFeatBg = Color(0xFFFFF3D6);
  static const Color badgeFeatFg = Color(0xFFB45309);
  static const Color availBg = Color(0xFFE6F9EE);
  static const Color availNoBg = Color(0xFFFDE8EE);
  static const Color availWarnBg = Color(0xFFFDF3E0);
  static const Color freeTagBg = Color(0xFFE6F9EE);
  static const Color softIconBg = Color(0xFFF4F1FF);
  static const Color chipSelectedBg = AppTheme.ink;
  static const Color navIndicator = Color(0xFFEFE9FF);
  static const Color navMuted = Color(0xFFA29EC4);
  static const Color star = Color(0xFFF59E0B);
  static const Color starText = Color(0xFFB45309);
  static const Color searchHint = Color(0xFF9B96BA);
  static const Color favMuted = Color(0xFFB9B4D6);
  static const Color sheetGrab = Color(0xFFE3DFF2);
  static const Color menuRowBorder = Color(0xFFF3F1FA);

  /// Prototype `#splash` gradient (`linear-gradient(160deg,#6d28d9,#4338ca 60%,#312e81)`).
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D28D9), Color(0xFF4338CA), Color(0xFF312E81)],
  );

  /// Prototype `#splash .logo` — 88×88, radius 26, white 14% fill, white 30% border.
  static const double splashLogoSize = 88;
  static const double splashLogoRadius = 26;
  static const Color splashLogoFill = Color(0x24FFFFFF);
  static const Color splashLogoBorder = Color(0x4DFFFFFF);
  static const Color splashSubtitle = Color(0xFFC9C2F5);

  /// Prototype `.btn` — `box-shadow: 0 8px 20px rgba(108,61,244,.3)`.
  static const BoxShadow ctaShadow = BoxShadow(
    color: Color(0x4D6C3DF4),
    blurRadius: 20,
    offset: Offset(0, 8),
  );

  /// Prototype `.steps` — 4px pill track, active = brand.
  static const Color stepsTrack = Color(0xFFECE9F6);

  /// Prototype `#nav` metrics.
  static const double navHeight = 88;
  static const double navIconPillWidth = 44;
  static const double navIconPillHeight = 27;

  /// Prototype thumb gradients `.g1`–`.g6`.
  static const List<LinearGradient> thumbGradients = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF34D399), Color(0xFF0D9488)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFBBF24), Color(0xFFEA580C)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF472B6), Color(0xFFA21CAF)],
    ),
  ];

  static LinearGradient thumbGradientFor(String seed) {
    if (seed.isEmpty) return thumbGradients.first;
    final h = seed.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    return thumbGradients[h % thumbGradients.length];
  }

  /// Home / explore category tiles from the prototype `CATS` list.
  ///
  /// Keys stay DB-compatible (`function_hall`, …) while labels/emojis/order
  /// match the HTML source of truth. Displays 8 primary categories.
  static const List<PrototypeCategory> homeCategories = [
    PrototypeCategory(
      key: 'function_hall',
      emoji: '🏛️',
      label: 'Function Halls',
    ),
    PrototypeCategory(key: 'stays', emoji: '🏨', label: 'Hotels / Rooms / Stays'),
    PrototypeCategory(key: 'pg', emoji: '🏠', label: 'PG / Co-Living'),
    PrototypeCategory(key: 'classes', emoji: '🎓', label: 'Classes / Institutes'),
    PrototypeCategory(key: 'meeting_room', emoji: '💼', label: 'Meeting Rooms / Coworking'),
    PrototypeCategory(key: 'sports_ground', emoji: '⚽', label: 'Sports / Courts / Grounds'),
    PrototypeCategory(key: 'events', emoji: '📅', label: 'Events'),
    PrototypeCategory(key: 'courses', emoji: '📚', label: 'Courses'),
  ];

  /// Explore filter chips from the prototype `CATCHIPS` list.
  static const List<PrototypeCategory> exploreChips = [
    PrototypeCategory(key: 'all', emoji: '✨', label: 'All'),
    PrototypeCategory(key: 'function_hall', emoji: '🏛️', label: 'Halls'),
    PrototypeCategory(key: 'stays', emoji: '🏨', label: 'Hotels / Stays'),
    PrototypeCategory(key: 'pg', emoji: '🏠', label: 'PG / Co-Living'),
    PrototypeCategory(key: 'classes', emoji: '🎓', label: 'Classes'),
    PrototypeCategory(key: 'meeting_room', emoji: '💼', label: 'Meetings'),
    PrototypeCategory(key: 'sports_ground', emoji: '⚽', label: 'Sports'),
    PrototypeCategory(key: 'events', emoji: '📅', label: 'Events'),
    PrototypeCategory(key: 'courses', emoji: '📚', label: 'Courses'),
  ];

  /// Prototype radius chips: 2 / 5 / 10 / 25 / Entire city (99).
  static const List<double> radiusOptionsKm = [2, 5, 10, 25, 99];

  /// Prototype `.catT` radius / emoji / label metrics.
  static const double categoryTileRadius = 18;
  static const double categoryEmojiSize = 23;
  static const double categoryLabelSize = 10;

  /// Text style that prefers platform emoji fonts over Plus Jakarta Sans.
  ///
  /// Theme-wide Latin fonts often lack emoji glyphs; without an explicit
  /// fallback (especially on Flutter web) category tiles render blank.
  static TextStyle emojiStyle({double fontSize = categoryEmojiSize}) =>
      TextStyle(
        fontSize: fontSize,
        height: 1.1,
        fontFamilyFallback: AppTheme.emojiFontFallbacks,
        // Clear inherited Latin family so fallbacks are used for emoji codepoints.
        fontFamily: '',
      );

  /// Resolve a display emoji: prefer non-blank [icon], else prototype map by slug.
  static String emojiForCategorySlug(String? slug, {String? icon}) {
    final trimmed = icon?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    if (slug == null || slug.isEmpty) return '📌';
    for (final c in homeCategories) {
      if (c.key == slug) return c.emoji;
    }
    for (final c in exploreChips) {
      if (c.key == slug) return c.emoji;
    }
    return switch (slug) {
      // Venues & Spaces
      'halls' || 'venues' || 'venue' || 'function_hall' => '🏛️',
      'marriage_hall' || 'marriage' => '💍',
      'banquet_hall' || 'banquet' => '🍽️',
      'convention_center' || 'convention' => '🏢',
      'conference' || 'conference_room' || 'conference_rooms' => '📊',
      'community_hall' => '👥',
      'party_hall' || 'parties' || 'party' => '🎉',
      'farm_house' || 'farmhouse' => '🌳',
      'auditorium' => '🎭',
      'exhibition_center' || 'exhibition' => '🖼️',
      'open_grounds' || 'open_ground' || 'open_ground_s' => '🌾',

      // Stays & Living
      'hotel' || 'resort' || 'stays' || 'hotel_resort' => '🏨',
      'pg' || 'pg_coliving' || 'co_living' => '🏠',

      // Business & Professional
      'conference_room' || 'confs' => '📊',
      'meeting_room' || 'meeting_rooms' || 'meeting' => '🤝',
      'coworking_space' || 'coworking' || 'work' || 'studios' => '💻',

      // Education & Training
      'training_institute' || 'training' || 'institute' || 'classroom' => '🎓',
      'tuition_center' || 'tuition' => '📚',
      'coaching_center' || 'coaching' => '✏️',
      'courses' => '📚',

      // Sports & Recreation
      'sports' || 'sports_ground' || 'sports_grounds' => '🏏',
      'cricket_ground' || 'cricket' => '🏏',
      'football_ground' || 'football' => '⚽',
      'indoor_stadium' || 'stadium' || 'indoor_stadiums' => '🏟️',
      'club_house' || 'clubhouse' => '🍸',

      // Entertainment & Culture
      'movie_theater' || 'cinema' => '🎬',

      // Government & Public
      'govt_hall' || 'ttd_hall' || 'govt' => '🏛️',

      // Services & Opportunities
      'local_jobs' || 'jobs' => '💼',

      // Devotional & Religious Events
      'devotional' || 'religious' => '🙏',
      'devotional_hindu' || 'hindu' => '🕉️',
      'devotional_muslim' || 'muslim' => '☪️',
      'devotional_christian' || 'christian' => '✝️',
      'devotional_buddhist' || 'buddhist' => '☸️',

      // Fallbacks
      'event_space' => '📅',
      _ => '🏛️',
    };
  }

  /// Prototype `.catT` — white card, line border, no shadow / no selected chrome.
  static BoxDecoration categoryTileDecoration({bool selected = false}) =>
      BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(categoryTileRadius),
        border: Border.all(
          color: selected ? AppTheme.brand : AppTheme.line,
          width: selected ? 1.5 : 1,
        ),
      );

  static String emojiForEventCategory(String name) => switch (name) {
    'meeting' => '🤝',
    'conference' => '🎤',
    'workshop' => '🎨',
    'sports' => '🏃',
    'entertainment' => '🎵',
    'cultural' => '🎭',
    'exhibition' => '📚',
    'community' => '🤝',
    _ => '📅',
  };

  /// Prototype `.rCard` — white + line, no default shadow.
  static BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
    color: AppTheme.card,
    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
    border: Border.all(
      color: selected ? AppTheme.brand : AppTheme.line,
      width: selected ? 1.5 : 1,
    ),
    boxShadow: selected
        ? [
            BoxShadow(
              color: AppTheme.brand.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ]
        : null,
  );

  /// Prototype `.searchFake` — `0 4px 14px rgba(108,61,244,.06)`.
  static BoxDecoration searchFieldDecoration() => BoxDecoration(
    color: AppTheme.card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppTheme.line),
    boxShadow: [
      BoxShadow(
        color: AppTheme.brand.withValues(alpha: 0.06),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// Time-of-day greeting matching prototype `Good evening 👋`.
  static String timeGreeting({DateTime? now}) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning 👋';
    if (h < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  static String radiusLabel(double km) =>
      km >= 99 ? 'Entire city' : '${km.toInt()} km';
}

class PrototypeCategory {
  const PrototypeCategory({
    required this.key,
    required this.emoji,
    required this.label,
  });

  final String key;
  final String emoji;
  final String label;
}

/// Prototype `.badge` chip (Venue / Institute / Event / Featured).
class PrototypeBadge extends StatelessWidget {
  const PrototypeBadge.venue({super.key})
    : label = '🏛️ Venue',
      background = PrototypeVisuals.badgeVenueBg,
      foreground = AppTheme.brand;

  const PrototypeBadge.institute({super.key})
    : label = '🎓 Institute',
      background = PrototypeVisuals.badgeClassBg,
      foreground = PrototypeVisuals.badgeClassFg;

  const PrototypeBadge.event({super.key})
    : label = '📅 Event',
      background = PrototypeVisuals.badgeEventBg,
      foreground = PrototypeVisuals.badgeEventFg;

  const PrototypeBadge.featured({super.key})
    : label = '⭐ Featured',
      background = PrototypeVisuals.badgeFeatBg,
      foreground = PrototypeVisuals.badgeFeatFg;

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontFamilyFallback: AppTheme.emojiFontFallbacks,
        ),
      ),
    );
  }
}

/// Circular favourite control matching prototype `.favBtn`.
class PrototypeFavButton extends StatelessWidget {
  const PrototypeFavButton({
    super.key,
    required this.isFavorite,
    this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(
        side: BorderSide(color: AppTheme.line),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_outline_rounded,
            size: 15,
            color: isFavorite ? AppTheme.danger : PrototypeVisuals.favMuted,
          ),
        ),
      ),
    );
  }
}

/// Prototype `.iconBtn` (42×42, radius 14).
class PrototypeIconButton extends StatelessWidget {
  const PrototypeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.showDot = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool showDot;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.line),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppTheme.ink, size: 19),
              if (showDot)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Prototype `.catT` category tile — emoji + label, no soft plate.
class PrototypeCategoryTile extends StatefulWidget {
  const PrototypeCategoryTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<PrototypeCategoryTile> createState() => _PrototypeCategoryTileState();
}

class _PrototypeCategoryTileState extends State<PrototypeCategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        // Prototype `.catT:active { transform: scale(.93) }`
        scale: _pressed ? 0.93 : 1,
        duration: AppMotion.fast,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          // Prototype: padding 13px 4px 11px
          padding: const EdgeInsets.fromLTRB(4, 13, 4, 11),
          decoration: PrototypeVisuals.categoryTileDecoration(
            selected: widget.selected,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.emoji,
                style: PrototypeVisuals.emojiStyle(),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: PrototypeVisuals.categoryLabelSize,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prototype `.chip` / `.chip.on` (ink fill when selected).
class PrototypeFilterChip extends StatelessWidget {
  const PrototypeFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
  });

  /// Optional leading emoji rendered with [PrototypeVisuals.emojiStyle].
  final String? emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppTheme.muted;
    return Material(
      color: selected ? AppTheme.ink : AppTheme.card,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppTheme.ink : AppTheme.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null && emoji!.trim().isNotEmpty) ...[
                Text(
                  emoji!.trim(),
                  style: PrototypeVisuals.emojiStyle(fontSize: 13),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  fontFamilyFallback: AppTheme.emojiFontFallbacks,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient thumb with large emoji (prototype `.rThumb` / `.em`).
class PrototypeEmojiThumb extends StatelessWidget {
  const PrototypeEmojiThumb({
    super.key,
    required this.emoji,
    required this.seed,
    this.width = 82,
    this.height = 88,
    this.radius = 15,
    this.emojiSize = 34,
    this.child,
  });

  final String emoji;
  final String seed;
  final double width;
  final double height;
  final double radius;
  final double emojiSize;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: PrototypeVisuals.thumbGradientFor(seed),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ?child,
          Center(
            child: Text(
              emoji,
              style: PrototypeVisuals.emojiStyle(fontSize: emojiSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototype `#nav` — frosted bar, 44×27 selected pill, 10px labels.
class PrototypeBottomNav extends StatelessWidget {
  const PrototypeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<PrototypeNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    // Prototype `#nav`: height 88, padding 10px 8px 22px (22 ≈ home-indicator).
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.line)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 10, 8, bottomInset > 0 ? bottomInset : 22),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrototypeNavDestination {
  const PrototypeNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final PrototypeNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.brand : PrototypeVisuals.navMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            width: PrototypeVisuals.navIconPillWidth,
            height: PrototypeVisuals.navIconPillHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? PrototypeVisuals.navIndicator : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 21,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
