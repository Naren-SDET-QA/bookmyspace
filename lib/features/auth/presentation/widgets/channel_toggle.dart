import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Two-segment channel selector (prototype `.seg`) used by the auth screens
/// to switch between Email and Phone one-time-code login/signup.
class ChannelToggle extends StatelessWidget {
  const ChannelToggle({
    super.key,
    required this.channels,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// Segment labels, e.g. `['Email', 'Phone']`.
  final List<String> channels;

  /// Index of the currently selected segment.
  final int selectedIndex;

  /// Called with the tapped segment index.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < channels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: selectedIndex == i
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    channels[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: selectedIndex == i
                          ? AppTheme.ink
                          : AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
