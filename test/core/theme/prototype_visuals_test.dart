import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/core/theme/prototype_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme tokens match prototype :root CSS', () {
    expect(AppTheme.brand, const Color(0xFF6C3DF4));
    expect(AppTheme.accent, const Color(0xFF4F46E5));
    expect(AppTheme.ink, const Color(0xFF17132B));
    expect(AppTheme.muted, const Color(0xFF6F6A8F));
    expect(AppTheme.surfaceLight, const Color(0xFFF4F2FB));
    expect(AppTheme.line, const Color(0xFFE9E6F5));
    expect(AppTheme.success, const Color(0xFF16A34A));
    expect(AppTheme.danger, const Color(0xFFE11D48));
    expect(AppTheme.warning, const Color(0xFFD97706));
    expect(AppTheme.pagePadding, 18);
    expect(AppTheme.cardRadius, 20);
    expect(AppTheme.light.colorScheme.primary, AppTheme.brand);
  });

  test('CATS order and emojis match prototype', () {
    expect(
      PrototypeVisuals.homeCategories.map((c) => c.emoji).toList(),
      ['🏛️', '🎓', '📅', '🤝', '🎤', '🎉', '🏆', '🎭'],
    );
    expect(
      PrototypeVisuals.homeCategories.map((c) => c.label).toList(),
      [
        'Function Halls',
        'Classes',
        'Events',
        'Meetings',
        'Conferences',
        'Parties',
        'Sports',
        'Shows',
      ],
    );
  });

  test('CATCHIPS order and emojis match prototype', () {
    expect(
      PrototypeVisuals.exploreChips.map((c) => '${c.emoji} ${c.label}').toList(),
      [
        '✨ All',
        '🏛️ Halls',
        '🎓 Classes',
        '📅 Events',
        '🤝 Meetings',
        '🎤 Conferences',
        '🎉 Parties',
        '🏆 Sports',
        '🎭 Shows',
      ],
    );
  });

  test('radius options include Entire city (99)', () {
    expect(PrototypeVisuals.radiusOptionsKm, [2, 5, 10, 25, 99]);
    expect(PrototypeVisuals.radiusLabel(99), 'Entire city');
    expect(PrototypeVisuals.radiusLabel(10), '10 km');
  });

  test('timeGreeting matches prototype dayparts', () {
    expect(
      PrototypeVisuals.timeGreeting(now: DateTime(2026, 8, 5, 9)),
      'Good morning 👋',
    );
    expect(
      PrototypeVisuals.timeGreeting(now: DateTime(2026, 8, 5, 14)),
      'Good afternoon 👋',
    );
    expect(
      PrototypeVisuals.timeGreeting(now: DateTime(2026, 8, 5, 19)),
      'Good evening 👋',
    );
  });

  test('emojiForCategorySlug coalesces blank icon to CATS map', () {
    expect(
      PrototypeVisuals.emojiForCategorySlug('function_hall', icon: ''),
      '🏛️',
    );
    expect(
      PrototypeVisuals.emojiForCategorySlug('classes', icon: '   '),
      '🎓',
    );
    expect(
      PrototypeVisuals.emojiForCategorySlug('meeting_room', icon: null),
      '🤝',
    );
    expect(
      PrototypeVisuals.emojiForCategorySlug('parties', icon: '🎉'),
      '🎉',
    );
    expect(
      PrototypeVisuals.emojiForCategorySlug('halls', icon: null),
      '🏛️',
    );
  });

  test('categoryTileDecoration has no shadow like prototype .catT', () {
    final deco = PrototypeVisuals.categoryTileDecoration();
    expect(deco.boxShadow, isNull);
    expect(deco.color, AppTheme.card);
    expect(deco.borderRadius, BorderRadius.circular(18));
  });

  test('rCard decoration has no default shadow', () {
    final deco = PrototypeVisuals.cardDecoration();
    expect(deco.boxShadow, isNull);
  });

  testWidgets('PrototypeCategoryTile paints emoji without soft plate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PrototypeCategoryTile(
            emoji: '🏛️',
            label: 'Function Halls',
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🏛️'), findsOneWidget);
    expect(find.text('Function Halls'), findsOneWidget);

    final emojiText = tester.widget<Text>(find.text('🏛️'));
    expect(
      emojiText.style?.fontFamilyFallback,
      containsAll(AppTheme.emojiFontFallbacks.take(2)),
    );
    expect(emojiText.style?.fontSize, PrototypeVisuals.categoryEmojiSize);
  });

  testWidgets('PrototypeBadge uppercases like CSS text-transform', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PrototypeBadge.venue()),
      ),
    );
    expect(find.text('🏛️ VENUE'), findsOneWidget);
  });

  testWidgets('search-style chips render CATCHIPS emojis under AppTheme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Wrap(
            children: [
              for (final chip in PrototypeVisuals.exploreChips)
                PrototypeFilterChip(
                  emoji: chip.emoji,
                  label: chip.label,
                  selected: chip.key == 'all',
                  onTap: () {},
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('✨'), findsOneWidget);
    expect(find.text('🏛️'), findsOneWidget);
    expect(find.text('Halls'), findsOneWidget);
  });
}
