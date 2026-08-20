import 'module_registration.dart';

enum ModuleProgressStep {
  registration,
  documents,
  payment,
  review,
  approved,
  completed,
}

List<ModuleProgressStep> moduleProgressSteps(ModuleFeatureConfig config) => [
  ModuleProgressStep.registration,
  if (config.documentsEnabled || config.documentUploadEnabled)
    ModuleProgressStep.documents,
  if (config.paymentEnabled) ModuleProgressStep.payment,
  if (config.approvalRequired) ModuleProgressStep.review,
  if (config.approvalRequired) ModuleProgressStep.approved,
  ModuleProgressStep.completed,
];
