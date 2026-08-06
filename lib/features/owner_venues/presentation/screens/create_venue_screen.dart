import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/maps/domain/geo_point.dart';
import '../../../../core/maps/presentation/map_view.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../providers/owner_venue_providers.dart';

/// A locally picked image file waiting to be uploaded on save.
class _PendingImage {
  const _PendingImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Screen for owners to create or edit a venue.
class CreateVenueScreen extends ConsumerStatefulWidget {
  const CreateVenueScreen({super.key, this.venue});

  final Venue? venue;

  @override
  ConsumerState<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends ConsumerState<CreateVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _postalController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _amenitiesController = TextEditingController();
  String? _selectedCategoryId;
  bool _submitting = false;
  late GeoPoint _location;
  final List<String> _imageUrls = [];
  final List<_PendingImage> _pendingImages = [];
  bool _ownerVerified = false;
  bool _hydrated = false;

  bool get _editing => widget.venue != null;

  /// Hall is customer-visible only when approved (published) by admin.
  bool get _venueIsLive => widget.venue?.isActive ?? false;

  bool get _fieldLocked => _ownerVerified;

  @override
  void initState() {
    super.initState();
    final v = widget.venue;
    if (v != null) {
      _ownerVerified = v.ownerVerified;
      _nameController.text = v.name;
      _descriptionController.text = v.description;
      _cityController.text = v.city;
      _stateController.text = v.state;
      _capacityController.text = '${v.capacity}';
      _priceController.text = '${v.pricingBaseAmount}';
      _address1Controller.text = v.addressLine1;
      _postalController.text = v.postalCode;
      _phoneController.text = v.phone;
      _websiteController.text = v.website;
      _selectedCategoryId = v.category?.id;
      _location = GeoPoint(v.latitude, v.longitude);
      _hydrateDetail(v.id);
    } else {
      _location = const GeoPoint(15.5057, 80.0495); // Ongole default
    }
  }

  Future<void> _hydrateDetail(String venueId) async {
    if (_hydrated) return;
    try {
      final detail = await ref
          .read(ownerVenueDetailProvider(venueId).future);
      if (!mounted) return;
      setState(() {
        _imageUrls
          ..clear()
          ..addAll(detail.images.map((i) => i.url).where((u) => u.isNotEmpty));
        _amenitiesController.text = detail.facilities
            .map((f) => f.facility)
            .where((f) => f.isNotEmpty)
            .join(', ');
        _ownerVerified = detail.venue.ownerVerified;
        _hydrated = true;
      });
    } catch (e) {
      if (mounted) {
        _hydrated = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load venue details: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _postalController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _amenitiesController.dispose();
    super.dispose();
  }

  List<String> get _amenities => _amenitiesController.text
      .split(RegExp(r'[,;\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _pickImages() async {
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pendingImages.add(_PendingImage(name: file.name, bytes: bytes));
    });
  }

  Future<String> _uploadImage(
    String venueId,
    _PendingImage image,
  ) async {
    final client = ref.read(supabaseProvider);
    final uid = client.auth.currentUser!.id;
    final safe = image.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '$uid/$venueId/${DateTime.now().microsecondsSinceEpoch}_$safe';
    await client.storage
        .from('venue-images')
        .uploadBinary(path, image.bytes);
    return client.storage.from('venue-images').getPublicUrl(path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final params = (
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        latitude: _location.latitude,
        longitude: _location.longitude,
        capacity: int.tryParse(_capacityController.text) ?? 50,
        pricingBaseAmount: double.tryParse(_priceController.text) ?? 0,
        addressLine1: _address1Controller.text.trim(),
        addressLine2: _address2Controller.text.trim(),
        postalCode: _postalController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim(),
        amenities: _amenities,
        imageUrls: List<String>.of(_imageUrls),
      );

      var venueId = '';
      if (_editing) {
        venueId = widget.venue!.id;
        await ref.read(updateVenueProvider((
          venueId: venueId,
          name: params.name,
          categoryId: params.categoryId,
          description: params.description,
          city: params.city,
          state: params.state,
          latitude: params.latitude,
          longitude: params.longitude,
          capacity: params.capacity,
          pricingBaseAmount: params.pricingBaseAmount,
          addressLine1: params.addressLine1,
          addressLine2: params.addressLine2,
          postalCode: params.postalCode,
          phone: params.phone,
          website: params.website,
          amenities: params.amenities,
          imageUrls: params.imageUrls,
        )).future);
      } else {
        final created = await ref.read(createVenueProvider(params).future);
        venueId = created.id;
      }

      if (_pendingImages.isNotEmpty && venueId.isNotEmpty) {
        final client = ref.read(supabaseProvider);
        final urls = List<String>.of(_imageUrls);
        for (final pending in _pendingImages) {
          urls.add(await _uploadImage(venueId, pending));
        }
        await client.rpc<void>('owner_replace_venue_images', params: {
          'p_venue_id': venueId,
          'p_images': [
            for (var i = 0; i < urls.length; i++)
              {
                'url': urls[i],
                'is_cover': i == 0,
                'sort_order': i,
                'alt_text': _nameController.text.trim(),
              },
          ],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editing
                  ? 'Hall updated successfully'
                  : 'Hall submitted for admin review',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(venueCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Hall' : 'Add Hall')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_editing && !_venueIsLive) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFAECBFA)),
                  ),
                  child: const Text(
                    '⏳ This hall is pending admin review and not yet visible '
                    'to customers. You will be notified once it is approved.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF174EA6),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_fieldLocked) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: const Text(
                    '🔒 Owner-verified venue — business identity fields are '
                    'protected and cannot be changed here. Contact support for '
                    'corrections. Description, pricing, amenities and images '
                    'remain editable.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8D4E00),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                enabled: !_fieldLocked,
                decoration: const InputDecoration(
                  labelText: 'Venue Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    AppValidators.required(v, fieldName: 'Name'),
              ),
              const SizedBox(height: 16),
              categories.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading categories: $e'),
                data: (cats) => DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  items: cats
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: _fieldLocked
                      ? null
                      : (v) => setState(() => _selectedCategoryId = v),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: AppValidators.description,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      enabled: !_fieldLocked,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          AppValidators.required(v, fieldName: 'City'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      enabled: !_fieldLocked,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          AppValidators.required(v, fieldName: 'State'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address1Controller,
                enabled: !_fieldLocked,
                decoration: const InputDecoration(
                  labelText: 'Address line 1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _address2Controller,
                      enabled: !_fieldLocked,
                      decoration: const InputDecoration(
                        labelText: 'Address line 2',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _postalController,
                      enabled: !_fieldLocked,
                      decoration: const InputDecoration(
                        labelText: 'PIN code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Location',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search an address or tap the map. '
                '${_location.latitude.toStringAsFixed(5)}, '
                '${_location.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                    ),
              ),
              const SizedBox(height: 8),
              MapView(
                initialCenter: _location,
                height: 160,
                pickOnTap: !_fieldLocked,
                showAddressSearch: !_fieldLocked,
                showUserLocation: true,
                markers: [MapMarkerData(point: _location)],
                onLocationPicked: (point) => setState(() => _location = point),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _capacityController,
                      decoration: const InputDecoration(
                        labelText: 'Capacity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          AppValidators.positiveInt(v, fieldName: 'capacity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Base Price (₹)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: AppValidators.nonNegativePrice,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      enabled: !_fieldLocked,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _websiteController,
                      enabled: !_fieldLocked,
                      decoration: const InputDecoration(
                        labelText: 'Website',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amenitiesController,
                decoration: const InputDecoration(
                  labelText: 'Amenities / features',
                  helperText: 'Comma-separated, e.g. Parking, AC, WiFi',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Text(
                'Photos',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              if (_imageUrls.isNotEmpty || _pendingImages.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _imageUrls.length; i++)
                      _ImageThumb(
                        label: i == 0 ? 'Cover' : null,
                        child: AppNetworkImage(
                          url: _imageUrls[i],
                          width: 96,
                          height: 96,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onRemove: () =>
                            setState(() => _imageUrls.removeAt(i)),
                      ),
                    for (var i = 0; i < _pendingImages.length; i++)
                      _ImageThumb(
                        label: 'New',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _pendingImages[i].bytes,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                        onRemove: () =>
                            setState(() => _pendingImages.removeAt(i)),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Upload photos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addImageUrlDialog(),
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Add image URL'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_editing ? 'Save Hall' : 'Create Hall'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addImageUrlDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add image URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'https://…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final url = controller.text.trim();
      if (url.isNotEmpty && url.startsWith('https://')) {
        setState(() => _imageUrls.add(url));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid https:// image URL')),
        );
      }
    }
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.child, this.label, required this.onRemove});

  final Widget child;
  final String? label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (label != null)
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.brand,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
