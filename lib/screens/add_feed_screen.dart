import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

class AddFeedScreen extends StatefulWidget {
  const AddFeedScreen({super.key});

  @override
  State<AddFeedScreen> createState() => _AddFeedScreenState();
}

class _AddFeedScreenState extends State<AddFeedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _feedTypeController = TextEditingController();
  final _animalTypeController = TextEditingController();
  final _priceController = TextEditingController();
  final _weightController = TextEditingController();
  final _unitController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _expiryController = TextEditingController();

  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  bool _isSubmitting = false;
  String _status = 'AVAILABLE';

  @override
  void dispose() {
    _feedNameController.dispose();
    _brandController.dispose();
    _feedTypeController.dispose();
    _animalTypeController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;

    const allowedExtensions = ['.jpg', '.jpeg', '.png'];
    int rejected = 0;
    final valid = <XFile>[];
    for (final file in files) {
      final lower = file.path.toLowerCase();
      final match = allowedExtensions.any((ext) => lower.endsWith(ext));
      if (match) {
        valid.add(file);
      } else {
        rejected++;
      }
    }

    if (!mounted) return;

    if (rejected > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Only JPEG and PNG images are supported.')),
        ),
      );
    }

    if (valid.isEmpty) return;

    setState(() {
      final remaining = 5 - _photos.length;
      if (remaining <= 0) return;
      _photos.addAll(valid.take(remaining));
    });
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (selected == null) return;
    _expiryController.text = selected.toIso8601String();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Add at least one photo'))),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);
    final api = context.read<AppState>().api;

    final fields = <String, String>{
      'feedName': _feedNameController.text.trim(),
      'brand': _brandController.text.trim(),
      'feedType': _feedTypeController.text.trim(),
      'animalType': _animalTypeController.text.trim(),
      'price': _priceController.text.trim(),
      'weight': _weightController.text.trim(),
      'unit': _unitController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'expiryDate': _expiryController.text.trim(),
      'status': _status,
    };

    fields.removeWhere((key, value) => value.isEmpty);

    try {
      await api.createFeed(fields: fields, photos: List.of(_photos));
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Feed listing created'))),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Failed to submit listing'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Add feed listing'))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                context.tr('Provide accurate nutritional info to help buyers.'),
              ),
              const SizedBox(height: 20),
              _SectionTitle(context.tr('Photos (1-5)')),
              const SizedBox(height: 12),
              _PhotoPicker(
                photos: _photos,
                onAdd: _pickPhotos,
                onRemove: (index) => setState(() => _photos.removeAt(index)),
              ),
              const SizedBox(height: 24),
              _SectionTitle(context.tr('Feed basics')),
              const SizedBox(height: 12),
              _Field(
                controller: _feedNameController,
                hint: context.tr('Feed name *'),
                validator: _requiredValidator(context),
              ),
              const SizedBox(height: 12),
              _Field(controller: _brandController, hint: context.tr('Brand')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _feedTypeController,
                      hint: context.tr('Feed type (e.g., concentrate)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _animalTypeController,
                      hint: context.tr('Animal type'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _priceController,
                      hint: context.tr('Price (ETB) *'),
                      keyboardType: TextInputType.number,
                      validator: _requiredValidator(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: context.tr('Status'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'AVAILABLE',
                          child: Text(context.tr('Available')),
                        ),
                        DropdownMenuItem(
                          value: 'LOW_STOCK',
                          child: Text(context.tr('Low stock')),
                        ),
                        DropdownMenuItem(
                          value: 'OUT_OF_STOCK',
                          child: Text(context.tr('Out of stock')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _weightController,
                      hint: context.tr('Weight (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _unitController,
                      hint: context.tr('Unit (e.g., per bag)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _expiryController,
                hint: context.tr('Expiry date (optional)'),
                readOnly: true,
                onTap: _pickExpiryDate,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _descriptionController,
                hint: context.tr('Description'),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              _SectionTitle(context.tr('Location')),
              const SizedBox(height: 12),
              _Field(
                controller: _locationController,
                hint: context.tr('City / region *'),
                validator: _requiredValidator(context),
                suffix: const Icon(
                  Icons.location_pin,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Publish listing')),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String? Function(String?) _requiredValidator(BuildContext context) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return context.tr('Required field');
      }
      return null;
    };
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onAdd,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: .2),
              ),
              color: Colors.white,
            ),
            child: const Center(
              child: Icon(
                Icons.add_a_photo_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(photos.length, (index) {
              final photo = photos[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(photo.path),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => onRemove(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ],
    );
  }
}
