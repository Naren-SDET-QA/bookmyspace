import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared modal bottom sheet that stays within the viewport on small screens.
///
/// - Caps height (~[maxHeightFactor] of screen) so sheets never climb under
///   the system nav / app bottom bar unchecked.
/// - Pads for keyboard ([MediaQuery.viewInsets]) and uses [SafeArea].
/// - Callers should put scrollable content inside (ListView /
///   [AppBottomSheetScrollBody]) when the body can grow past the max height.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool useRootNavigator = false,
  Color? backgroundColor,
  double maxHeightFactor = 0.85,
  ShapeBorder? shape,
}) {
  assert(maxHeightFactor > 0 && maxHeightFactor <= 1);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    backgroundColor: backgroundColor ?? AppTheme.card,
    shape:
        shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final maxHeight = media.size.height * maxHeightFactor;
      final keyboard = media.viewInsets.bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: builder(sheetContext),
          ),
        ),
      );
    },
  );
}

/// Scrollable sheet body with standard horizontal/vertical padding.
class AppBottomSheetScrollBody extends StatelessWidget {
  const AppBottomSheetScrollBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 0, 18, 18),
    this.controller,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: padding,
      child: child,
    );
  }
}
