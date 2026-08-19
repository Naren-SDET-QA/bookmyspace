import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../domain/owner_listing_draft.dart';
import '../providers/owner_venue_providers.dart';

/// Owner create / edit listing. Reuses `create_owner_venue`,
/// `update_owner_venue`, `venue_images` and `venue_facilities`.
class CreateVenueScreen extends ConsumerStatefulWidget {
  const CreateVenueScreen({super.key, this.venueId});

  final String? venueId;

  bool get isEditing => venueId != null && venueId!.isNotEmpty;

  @override
  ConsumerState<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends ConsumerState<CreateVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _addressController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _latController = TextEditingController(text: '17.3850');
  final _lngController = TextEditingController(text: '78.4867');
  final _mapController = MapController();

  CustomerSection _section = CustomerSection.functionHalls;
  String? _catalogCategoryId;
  final List<OwnerListingPhoto> _photos = [];
  final _picker = ImagePicker();
  final Set<String> _amenityIds = {};
  bool _publish = false;
  bool _submitting = false;
  bool _hydrated = false;
  String? _loadError;

  static const _defaultLat = 17.3850;
  static const _defaultLng = 78.4867;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _photoUrlController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final list = await ref.read(myVenuesProvider.future);
      Venue? venue;
      for (final item in list) {
        if (item.id == widget.venueId) {
          venue = item;
          break;
        }
      }
      venue ??= await ref.read(venueDetailsProvider(widget.venueId!).future);
      if (!mounted) return;
      setState(() {
        _hydrateFrom(venue!);
        _hydrated = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  void _hydrateFrom(Venue venue) {
    _nameController.text = venue.name;
    _descriptionController.text = venue.description;
    _cityController.text = venue.city;
    _stateController.text = venue.state;
    _addressController.text = venue.addressLine1;
    _capacityController.text = venue.capacity > 0 ? '${venue.capacity}' : '';
    _priceController.text = venue.pricingBaseAmount > 0
        ? venue.pricingBaseAmount.toStringAsFixed(0)
        : '';
    _latController.text = venue.latitude.toStringAsFixed(4);
    _lngController.text = venue.longitude.toStringAsFixed(4);
    _photos
      ..clear()
      ..addAll(
        venue.images.map((image) => OwnerListingPhoto(remoteUrl: image.url)),
      );
    _section =
        CustomerSectionCatalog.sectionForVenue(venue) ??
        CustomerSection.functionHalls;
    _catalogCategoryId = _inferCatalogCategory(venue, _section);
    _publish = venue.isActive;
    _amenityIds
      ..clear()
      ..addAll(_matchingAmenityIds(venue, _section));
  }

  String? _inferCatalogCategory(Venue venue, CustomerSection section) {
    final slug = venue.category?.slug.toLowerCase() ?? '';
    for (final category in CustomerSectionCatalog.ownerCategories(section)) {
      if (CustomerSectionCatalog.matchesVenue(venue, section, category.id) ||
          slug == category.id) {
        return category.id;
      }
    }
    final first = CustomerSectionCatalog.ownerCategories(section);
    return first.isEmpty ? null : first.first.id;
  }

  Set<String> _matchingAmenityIds(Venue venue, CustomerSection section) {
    final hay = [
      ...venue.facilities.map((f) => f.facility),
      venue.description,
    ].join(' ').toLowerCase();
    return CustomerSectionCatalog.amenityFilters(section)
        .where((spec) => spec.keywords.any(hay.contains))
        .map((spec) => spec.id)
        .toSet();
  }

  double get _latitude => double.tryParse(_latController.text) ?? _defaultLat;
  double get _longitude => double.tryParse(_lngController.text) ?? _defaultLng;

  void _onSectionChanged(CustomerSection section) {
    setState(() {
      _section = section;
      _catalogCategoryId = null;
      _amenityIds.clear();
    });
  }

  void _addPhotoUrl() {
    final url = _photoUrlController.text.trim();
    if (url.isEmpty) return;
    if (_photos.length >= OwnerListingDraft.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 photos per listing')),
      );
      return;
    }
    setState(() {
      _photos.add(OwnerListingPhoto(remoteUrl: url));
      _photoUrlController.clear();
    });
  }

  String _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/jpeg';
  }

  Future<void> _addPickedFiles(List<XFile> files) async {
    for (final file in files) {
      if (_photos.length >= OwnerListingDraft.maxPhotos) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 6 photos per listing')),
          );
        }
        break;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > OwnerListingPhoto.maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} is larger than 5 MB')),
          );
        }
        continue;
      }
      setState(() {
        _photos.add(
          OwnerListingPhoto(
            bytes: bytes,
            fileName: file.name.isEmpty ? 'photo.jpg' : file.name,
            contentType: _contentTypeForName(file.name),
          ),
        );
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final remaining = OwnerListingDraft.maxPhotos - _photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 photos per listing')),
      );
      return;
    }
    final files = await _picker.pickMultiImage(
      limit: remaining,
      imageQuality: 85,
    );
    if (files.isEmpty) return;
    await _addPickedFiles(files);
  }

  Future<void> _pickFromCamera() async {
    if (kIsWeb) {
      await _pickFromGallery();
      return;
    }
    if (_photos.length >= OwnerListingDraft.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 photos per listing')),
      );
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return;
    await _addPickedFiles([file]);
  }

  void _movePhoto(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _photos.length) return;
    setState(() {
      final url = _photos.removeAt(index);
      _photos.insert(next, url);
    });
  }

  void _setCover(int index) {
    if (index <= 0 || index >= _photos.length) return;
    setState(() {
      final url = _photos.removeAt(index);
      _photos.insert(0, url);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_catalogCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a category in this section')),
      );
      return;
    }

    final categories = await ref.read(venueCategoriesProvider.future);
    late final VenueCategory dbCategory;
    try {
      dbCategory = CustomerSectionCatalog.resolveDbCategory(
        dbCategories: categories,
        section: _section,
        catalogCategoryId: _catalogCategoryId!,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    String? categoryLabel;
    for (final category in CustomerSectionCatalog.ownerCategories(_section)) {
      if (category.id == _catalogCategoryId) {
        categoryLabel = category.label;
        break;
      }
    }
    final amenityLabels = CustomerSectionCatalog.amenityFilters(_section)
        .where((spec) => _amenityIds.contains(spec.id))
        .map((spec) => spec.label)
        .toList();
    final facilities = [
      if (categoryLabel != null) categoryLabel,
      ...amenityLabels,
    ];

    setState(() => _submitting = true);
    try {
      final venue = await ref.read(ownerVenueRepositoryProvider).saveListing(
        venueId: widget.isEditing ? widget.venueId : null,
        draft: OwnerListingDraft(
          name: _nameController.text.trim(),
          section: _section,
          catalogCategoryId: _catalogCategoryId!,
          categoryId: dbCategory.id,
          description: _descriptionController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          addressLine1: _addressController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          capacity: int.tryParse(_capacityController.text) ?? 1,
          pricingBaseAmount: double.tryParse(_priceController.text) ?? 0,
          photos: List<OwnerListingPhoto>.from(_photos),
          facilities: facilities,
          publish: _publish,
        ),
      );
      ref.invalidate(myVenuesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Listing updated'
                : (_publish ? 'Listing published' : 'Listing saved as draft'),
          ),
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(venue);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = CustomerSectionCatalog.ownerCategories(_section);
    final institute = !_section.isBookable;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit listing' : 'Create listing'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: 'Preview',
              onPressed: () =>
                  context.push('/venues/${widget.venueId}'),
              icon: const Icon(Icons.visibility_outlined),
            ),
        ],
      ),
      body: widget.isEditing && !_hydrated && _loadError == null
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : ResponsiveLayoutBuilder(
              builder: (context, responsive) {
                return Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      responsive.horizontalPadding,
                      16,
                      responsive.horizontalPadding,
                      32,
                    ),
                    children: [
                      Text(
                        'Section',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final section in CustomerSection.values)
                            ChoiceChip(
                              key: ValueKey('owner_section_${section.id}'),
                              label: Text(
                                '${section.emoji} ${section.title}',
                              ),
                              selected: _section == section,
                              onSelected: (_) => _onSectionChanged(section),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Category',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in categories)
                            ChoiceChip(
                              key: ValueKey(
                                'owner_category_${category.id}',
                              ),
                              label: Text(
                                '${category.emoji} ${category.label}',
                              ),
                              selected: _catalogCategoryId == category.id,
                              onSelected: (_) => setState(
                                () => _catalogCategoryId = category.id,
                              ),
                            ),
                        ],
                      ),
                      if (institute) ...[
                        const SizedBox(height: 12),
                        const _InstituteNotice(),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('owner_listing_name'),
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: institute
                              ? 'Institute / class name'
                              : 'Listing name',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('owner_listing_description'),
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Description is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address / area',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('owner_listing_city'),
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('owner_listing_state'),
                              controller: _stateController,
                              decoration: const InputDecoration(
                                labelText: 'State',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('owner_listing_capacity'),
                              controller: _capacityController,
                              decoration: InputDecoration(
                                labelText: institute
                                    ? 'Batch size'
                                    : _section == CustomerSection.lodgeRooms
                                    ? 'Rooms / occupancy'
                                    : _section == CustomerSection.pgHostels
                                    ? 'Beds / occupancy'
                                    : 'Capacity',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final n = int.tryParse(v);
                                if (n == null || n <= 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('owner_listing_price'),
                              controller: _priceController,
                              decoration: InputDecoration(
                                labelText: institute
                                    ? 'Fee from (₹)'
                                    : 'Base price (₹)',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final n = double.tryParse(v);
                                if (n == null || n < 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Available fields',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final spec
                              in CustomerSectionCatalog.amenityFilters(
                                _section,
                              ))
                            FilterChip(
                              label: Text('${spec.emoji} ${spec.label}'),
                              selected: _amenityIds.contains(spec.id),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _amenityIds.add(spec.id);
                                  } else {
                                    _amenityIds.remove(spec.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _PhotoEditor(
                        photos: _photos,
                        urlController: _photoUrlController,
                        onAddUrl: _addPhotoUrl,
                        onPickGallery: _pickFromGallery,
                        onPickCamera: _pickFromCamera,
                        onRemove: (i) => setState(() => _photos.removeAt(i)),
                        onMove: _movePhoto,
                        onCover: _setCover,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latController,
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lngController,
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _OwnerMapPicker(
                        latitude: _latitude,
                        longitude: _longitude,
                        controller: _mapController,
                        onPicked: (point) {
                          setState(() {
                            _latController.text =
                                point.latitude.toStringAsFixed(4);
                            _lngController.text =
                                point.longitude.toStringAsFixed(4);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        key: const Key('owner_listing_publish_switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Published'),
                        subtitle: Text(
                          institute
                              ? 'Visible as an advertising listing (Call / WhatsApp only)'
                              : 'Visible to customers in this section',
                        ),
                        value: _publish,
                        onChanged: (v) => setState(() => _publish = v),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('owner_listing_save'),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.isEditing
                                    ? 'Save listing'
                                    : (_publish
                                          ? 'Create & publish'
                                          : 'Save draft'),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _InstituteNotice extends StatelessWidget {
  const _InstituteNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Institutes / Classes are advertising listings only. Customers can call, WhatsApp or open the map — they cannot book hall slots.',
        ),
      ),
    );
  }
}

class _PhotoEditor extends StatelessWidget {
  const _PhotoEditor({
    required this.photos,
    required this.urlController,
    required this.onAddUrl,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemove,
    required this.onMove,
    required this.onCover,
  });

  final List<OwnerListingPhoto> photos;
  final TextEditingController urlController;
  final VoidCallback onAddUrl;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final ValueChanged<int> onRemove;
  final void Function(int index, int delta) onMove;
  final ValueChanged<int> onCover;

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < OwnerListingDraft.maxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos (${photos.length}/${OwnerListingDraft.maxPhotos})',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('owner_photo_pick'),
              onPressed: canAdd ? onPickGallery : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photos'),
            ),
            OutlinedButton.icon(
              key: const Key('owner_photo_camera'),
              onPressed: canAdd ? onPickCamera : null,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('owner_photo_url'),
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Or paste image URL',
                  border: OutlineInputBorder(),
                ),
                enabled: canAdd,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              key: const Key('owner_photo_add'),
              onPressed: canAdd ? onAddUrl : null,
              child: const Text('Add'),
            ),
          ],
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = photos[index];
                return SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: photo.bytes != null
                                    ? Image.memory(
                                        photo.bytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : AppNetworkImage(
                                        url: photo.remoteUrl,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            if (index == 0)
                              const Positioned(
                                left: 4,
                                bottom: 4,
                                child: Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    'COVER',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 18,
                            onPressed: index == 0
                                ? null
                                : () => onMove(index, -1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            iconSize: 18,
                            onPressed: index == 0
                                ? null
                                : () => onCover(index),
                            icon: const Icon(Icons.star_outline),
                          ),
                          IconButton(
                            iconSize: 18,
                            onPressed: () => onRemove(index),
                            icon: const Icon(Icons.close),
                          ),
                          IconButton(
                            iconSize: 18,
                            onPressed: index == photos.length - 1
                                ? null
                                : () => onMove(index, 1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _OwnerMapPicker extends StatelessWidget {
  const _OwnerMapPicker({
    required this.latitude,
    required this.longitude,
    required this.controller,
    required this.onPicked,
  });

  final double latitude;
  final double longitude;
  final MapController controller;
  final ValueChanged<LatLng> onPicked;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: point,
            initialZoom: 13,
            onTap: (tap, latLng) => onPicked(latLng),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bookmyspace.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: AppTheme.brand,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
