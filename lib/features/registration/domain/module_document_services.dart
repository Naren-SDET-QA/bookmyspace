import 'dart:typed_data';

class PickedDocument {
  const PickedDocument({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String name;
  final String mimeType;
}

abstract interface class DocumentPickerService {
  Future<PickedDocument?> pick();
}

abstract interface class DocumentUploadService {
  Future<void> upload(PickedDocument document);
  Future<void> remove();
}

class UnsupportedDocumentPicker implements DocumentPickerService {
  const UnsupportedDocumentPicker();
  @override
  Future<PickedDocument?> pick() => throw UnsupportedError(
    'Document picker is not configured for this platform',
  );
}
