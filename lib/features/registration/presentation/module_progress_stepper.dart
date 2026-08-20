import 'package:flutter/material.dart';
import '../domain/module_progress.dart';

class ModuleProgressStepper extends StatelessWidget {
  const ModuleProgressStepper({
    super.key,
    required this.steps,
    required this.current,
  });
  final List<ModuleProgressStep> steps;
  final ModuleProgressStep current;

  String _label(ModuleProgressStep step) => switch (step) {
    ModuleProgressStep.registration => 'Registration',
    ModuleProgressStep.documents => 'Documents',
    ModuleProgressStep.payment => 'Payment',
    ModuleProgressStep.review => 'Review',
    ModuleProgressStep.approved => 'Approved',
    ModuleProgressStep.completed => 'Completed',
  };

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: steps.map((step) {
      final active = step == current;
      return Chip(
        avatar: Icon(
          active ? Icons.radio_button_checked : Icons.check_circle_outline,
          size: 18,
        ),
        label: Text(_label(step)),
      );
    }).toList(),
  );
}
