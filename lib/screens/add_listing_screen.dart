import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  bool _isSubmitting = false;
  String? _selectedAnimalType;

  static const _animalTypeOptions = [
    _AnimalTypeOption('Cattle', 'CATTLE'),
    _AnimalTypeOption('Cow', 'COW'),
    _AnimalTypeOption('Goat', 'GOAT'),
    _AnimalTypeOption('Sheep', 'SHEEP'),
    _AnimalTypeOption('Camel', 'CAMEL'),
    _AnimalTypeOption('Chicken', 'CHICKEN'),
    _AnimalTypeOption('Fish', 'FISH'),
    _AnimalTypeOption('Bird', 'BIRD'),
    _AnimalTypeOption('Turkey', 'TURKEY'),
    _AnimalTypeOption('Rabbit', 'RABBIT'),
    _AnimalTypeOption('Snail', 'SNAIL'),
    _AnimalTypeOption('Grass Cutter', 'GRASS_CUTTER'),
    _AnimalTypeOption('Cat', 'CAT'),
    _AnimalTypeOption('Custom / other', 'CUSTOM'),
  ];

  @override
  void dispose() {
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final selected = await _picker.pickMultiImage();
    if (selected.isEmpty) return;

    // Allow only jpeg / png as required by backend
    const allowedExtensions = ['.jpg', '.jpeg', '.png'];
    final valid = <XFile>[];
    int rejected = 0;

    for (final file in selected) {
      final path = file.path.toLowerCase();
      final isAllowed = allowedExtensions.any((ext) => path.endsWith(ext));
      if (isAllowed) {
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
      final remainingSlots = 5 - _photos.length;
      _photos.addAll(valid.take(remainingSlots));
    });
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

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AppState>().api;

    final selectedType = _selectedAnimalType;
    if (selectedType == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Select a livestock type'))),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    String resolvedType;
    if (selectedType == 'CUSTOM') {
      final customValue = _customTypeController.text.trim();
      if (customValue.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('Enter your livestock name'))),
        );
        setState(() => _isSubmitting = false);
        return;
      }
      resolvedType = customValue.toUpperCase();
    } else {
      resolvedType = selectedType;
    }

    final fields = <String, String>{
      'animalType': resolvedType,
      'breed': _breedController.text.trim(),
      'age': _ageController.text.trim(),
      'weight': _weightController.text.trim(),
      'price': _priceController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'status': 'AVAILABLE',
    };

    try {
      await api.createAnimal(fields: fields, photos: _photos);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Listing created successfully'))),
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Add new listing'),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Text(
                //   context.tr('Add new listing'),
                //   style: theme.textTheme.headlineMedium?.copyWith(
                //     fontWeight: FontWeight.w700,
                //   ),
                // ),
                const SizedBox(height: 8),
                Text(context.tr('Share accurate info to build trust.')),
                const SizedBox(height: 20),
                _PhotoUploader(
                  photos: _photos,
                  onAdd: _pickPhotos,
                  onRemove: (index) => setState(() {
                    _photos.removeAt(index);
                  }),
                ),
                const SizedBox(height: 20),
                _SectionLabel(label: context.tr('Basic information')),
                const SizedBox(height: 12),
                Text(
                  context.tr('Livestock type *'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedAnimalType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: context.tr('Select a livestock type'),
                  ),
                  items: _animalTypeOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(context.tr(option.labelKey)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAnimalType = value;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? context.tr('Select a livestock type')
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Choose a preset type or pick Custom to write your own name. Use the next field to add nicknames buyers expect.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (_selectedAnimalType == 'CUSTOM') ...[
                  const SizedBox(height: 12),
                  _OutlinedField(
                    controller: _customTypeController,
                    hint: context.tr('Type name (e.g., Donkey)'),
                    validator: (value) {
                      if (_selectedAnimalType != 'CUSTOM') return null;
                      if (value == null || value.trim().isEmpty) {
                        return context.tr('Enter your livestock name');
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _OutlinedField(
                  controller: _breedController,
                  hint: context.tr('Display name / breed (optional)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OutlinedField(
                        controller: _ageController,
                        hint: context.tr('Age (e.g., 2 years)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OutlinedField(
                        controller: _weightController,
                        hint: context.tr('Weight (kg)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _OutlinedField(
                  controller: _priceController,
                  hint: context.tr('Price (ETB)'),
                  keyboardType: TextInputType.number,
                  prefix: const Icon(
                    Icons.currency_exchange_rounded,
                    color: AppColors.primaryGreen,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.tr('Required')
                      : null,
                ),
                const SizedBox(height: 12),
                _OutlinedField(
                  controller: _descriptionController,
                  hint: context.tr('Description'),
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                _SectionLabel(label: context.tr('Location')),
                const SizedBox(height: 12),
                _OutlinedField(
                  controller: _locationController,
                  hint: context.tr('Select region/city'),
                  suffix: const Icon(
                    Icons.location_pin,
                    color: AppColors.primaryGreen,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.tr('Required')
                      : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.tr('Submit listing')),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

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

class _OutlinedField extends StatelessWidget {
  const _OutlinedField({
    required this.hint,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
    this.controller,
  });

  final String hint;
  final Widget? prefix;
  final Widget? suffix;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
      ),
    );
  }
}

class _PhotoUploader extends StatelessWidget {
  const _PhotoUploader({
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
        _SectionLabel(label: context.tr('Photos (1-5)')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  height: 140,
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(photos.length, (index) {
                  final photo = photos[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          File(photo.path),
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 70,
                            height: 70,
                            color: AppColors.background,
                            child: const Icon(Icons.image),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemove(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
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
            ),
          ],
        ),
      ],
    );
  }
}

class _AnimalTypeOption {
  const _AnimalTypeOption(this.labelKey, this.value);

  final String labelKey;
  final String value;
}
