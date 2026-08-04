import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/validators/app_validators.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/domain/venue.dart';
import '../providers/owner_venue_providers.dart';

/// Screen for owners to create a new venue.
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
  String? _selectedCategoryId;
  bool _submitting = false;

  bool get _editing => widget.venue != null;

  @override
  void initState() {
    super.initState();
    final v = widget.venue;
    if (v != null) {
      _nameController.text = v.name;
      _descriptionController.text = v.description;
      _cityController.text = v.city;
      _stateController.text = v.state;
      _capacityController.text = '${v.capacity}';
      _priceController.text = '${v.pricingBaseAmount}';
      _selectedCategoryId = v.category?.id;
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
    super.dispose();
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
        latitude: 17.3850,
        longitude: 78.4867,
        capacity: int.tryParse(_capacityController.text) ?? 50,
        pricingBaseAmount: double.tryParse(_priceController.text) ?? 0,
      );
      if (_editing) {
        await ref.read(
          updateVenueProvider((
            venueId: widget.venue!.id,
            name: params.name,
            categoryId: params.categoryId,
            description: params.description,
            city: params.city,
            state: params.state,
            latitude: params.latitude,
            longitude: params.longitude,
            capacity: params.capacity,
            pricingBaseAmount: params.pricingBaseAmount,
          )).future,
        );
      } else {
        await ref.read(createVenueProvider(params).future);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editing
                  ? 'Hall updated successfully'
                  : 'Hall created successfully',
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Venue Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => AppValidators.required(v, fieldName: 'Name'),
            ),
            const SizedBox(height: 16),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading categories: $e'),
              data: (cats) => DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                items: cats
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
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
    );
  }
}
