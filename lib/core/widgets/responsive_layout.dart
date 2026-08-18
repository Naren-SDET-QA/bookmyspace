import 'package:flutter/material.dart';

/// Screen width breakpoints based on Material 3 specifications.
enum ResponsiveWindowSizeClass {
  compact,   // < 600dp (standard portrait phones)
  medium,    // 600dp - 839dp (foldables, small tablets, portrait tablets)
  expanded,  // 840dp - 1199dp (medium/large tablets, desktop)
  extraWide, // >= 1200dp (extra-wide tablet landscape, large monitors)
}

/// Sizing and layout metrics computed for the current screen constraints.
class ResponsiveInfo {
  const ResponsiveInfo({
    required this.windowClass,
    required this.availableWidth,
    required this.availableHeight,
    required this.isCompact,
    required this.isMedium,
    required this.isExpanded,
    required this.isExtraWide,
    required this.isTabletOrLandscape,
    required this.categoryColumns,
    required this.categoryAspectRatio,
    required this.resultsColumns,
    required this.resultsAspectRatio,
    required this.horizontalPadding,
    required this.gridSpacing,
    required this.maxContentWidth,
  });

  final ResponsiveWindowSizeClass windowClass;
  final double availableWidth;
  final double availableHeight;
  final bool isCompact;
  final bool isMedium;
  final bool isExpanded;
  final bool isExtraWide;
  final bool isTabletOrLandscape;
  final int categoryColumns;
  final double categoryAspectRatio;
  final int resultsColumns;
  final double resultsAspectRatio;
  final double horizontalPadding;
  final double gridSpacing;
  final double maxContentWidth;

  factory ResponsiveInfo.fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    final ResponsiveWindowSizeClass windowClass;
    if (width < 600) {
      windowClass = ResponsiveWindowSizeClass.compact;
    } else if (width < 840) {
      windowClass = ResponsiveWindowSizeClass.medium;
    } else if (width < 1200) {
      windowClass = ResponsiveWindowSizeClass.expanded;
    } else {
      windowClass = ResponsiveWindowSizeClass.extraWide;
    }

    final isCompact = windowClass == ResponsiveWindowSizeClass.compact;
    final isMedium = windowClass == ResponsiveWindowSizeClass.medium;
    final isExpanded = windowClass == ResponsiveWindowSizeClass.expanded;
    final isExtraWide = windowClass == ResponsiveWindowSizeClass.extraWide;
    final isTabletOrLandscape = !isCompact;

    // Responsive category columns and dynamic aspect ratios
    final int categoryColumns;
    final double categoryAspectRatio;
    if (isCompact) {
      categoryColumns = 1;
      categoryAspectRatio = width < 360 ? 2.3 : 2.7;
    } else if (isMedium) {
      categoryColumns = 2;
      categoryAspectRatio = 2.1;
    } else if (isExpanded) {
      categoryColumns = 2;
      categoryAspectRatio = 1.9;
    } else {
      // Extra-wide landscape: 4 columns in a single balanced horizontal hero row
      categoryColumns = 4;
      categoryAspectRatio = 1.35;
    }

    // Responsive venue/space result cards columns and aspect ratios
    final int resultsColumns;
    final double resultsAspectRatio;
    if (isCompact) {
      resultsColumns = 1;
      resultsAspectRatio = 0.88;
    } else if (isMedium) {
      resultsColumns = 2;
      resultsAspectRatio = 0.82;
    } else if (isExpanded) {
      resultsColumns = 3;
      resultsAspectRatio = 0.78;
    } else {
      resultsColumns = 4;
      resultsAspectRatio = 0.75;
    }

    final double horizontalPadding = isCompact
        ? 16.0
        : isMedium
            ? 24.0
            : isExpanded
                ? 32.0
                : 40.0;

    final double gridSpacing = isCompact ? 12.0 : 16.0;

    return ResponsiveInfo(
      windowClass: windowClass,
      availableWidth: width,
      availableHeight: height,
      isCompact: isCompact,
      isMedium: isMedium,
      isExpanded: isExpanded,
      isExtraWide: isExtraWide,
      isTabletOrLandscape: isTabletOrLandscape,
      categoryColumns: categoryColumns,
      categoryAspectRatio: categoryAspectRatio,
      resultsColumns: resultsColumns,
      resultsAspectRatio: resultsAspectRatio,
      horizontalPadding: horizontalPadding,
      gridSpacing: gridSpacing,
      maxContentWidth: 1280.0,
    );
  }
}

/// A responsive container that measures available space, calculates sizing metrics,
/// and constrains content width for optimal readability across phones, tablets, and desktop.
class ResponsiveLayoutBuilder extends StatelessWidget {
  const ResponsiveLayoutBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, ResponsiveInfo responsive) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveInfo.fromConstraints(constraints);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
            child: builder(context, responsive),
          ),
        );
      },
    );
  }
}
