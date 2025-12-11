import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

class AddVetDrugScreen extends StatefulWidget {
  const AddVetDrugScreen({super.key});

  @override
  State<AddVetDrugScreen> createState() => _AddVetDrugScreenState();
}

class _AddVetDrugScreenState extends State<AddVetDrugScreen> {
  final _formKey = GlobalKey<FormState>();
  final _drugNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController();
  final _stockController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _usageController = TextEditingController();
  final _dosageController = TextEditingController();
  final _storageController = TextEditingController();
  final _deliveryRegionsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _photo;
  bool _isSubmitting = false;
  String _status = 'AVAILABLE';

  @override
  void dispose() {
    _drugNameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    _manufacturerController.dispose();
    _usageController.dispose();
    _dosageController.dispose();
    _storageController.dispose();
    _deliveryRegionsController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _photo = image);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AppState>().api;

    final fields = <String, String>{
      'drugName': _drugNameController.text.trim(),
      'brand': _brandController.text.trim(),
      'status': _status,
      'description': _descriptionController.text.trim(),
      'category': _categoryController.text.trim(),
      'price': _priceController.text.trim(),
      'unit': _unitController.text.trim(),
      'stock': _stockController.text.trim(),
      'manufacturer': _manufacturerController.text.trim(),
      'usage': _usageController.text.trim(),
      'dosage': _dosageController.text.trim(),
      'storage': _storageController.text.trim(),
      'deliveryRegions': _deliveryRegionsController.text.trim(),
      'location': _locationController.text.trim(),
    };

    try {
      await api.createVetDrug(fields: fields, photo: _photo);
      messenger.showSnackBar(
        const SnackBar(content: Text('Vet listing created')),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to submit listing')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add vet supply')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'Provide accurate medical instructions to keep farmers safe.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _SectionTitle('Cover photo'),
              const SizedBox(height: 12),
              _PhotoPicker(
                photo: _photo,
                onTap: _pickPhoto,
                onClear: () {
                  setState(() => _photo = null);
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle('Product basics'),
              const SizedBox(height: 12),
              _Field(
                controller: _drugNameController,
                hint: 'Drug name *',
                validator: _required,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _brandController,
                hint: 'Brand (e.g., VetCare)',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _categoryController,
                hint: 'Category (e.g., Antibiotic)',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _priceController,
                      hint: 'Price (ETB) *',
                      keyboardType: TextInputType.number,
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _unitController,
                      hint: 'Unit (e.g., per vial)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _stockController,
                      hint: 'Stock quantity',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'AVAILABLE',
                          child: Text('Available'),
                        ),
                        DropdownMenuItem(
                          value: 'LOW_STOCK',
                          child: Text('Low stock'),
                        ),
                        DropdownMenuItem(
                          value: 'OUT_OF_STOCK',
                          child: Text('Out of stock'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(controller: _manufacturerController, hint: 'Manufacturer'),
              const SizedBox(height: 12),
              _Field(
                controller: _descriptionController,
                hint: 'Short description',
                maxLines: 3,
                validator: _required,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _locationController,
                hint: 'Location (city / region)',
                validator: _required,
              ),
              const SizedBox(height: 24),
              _SectionTitle('Dosage & usage'),
              const SizedBox(height: 12),
              _Field(
                controller: _usageController,
                hint: 'Usage instructions',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _dosageController,
                hint: 'Dosage instructions',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _storageController,
                hint: 'Storage conditions',
              ),
              const SizedBox(height: 24),
              _SectionTitle('Delivery details'),
              const SizedBox(height: 12),
              _Field(
                controller: _deliveryRegionsController,
                hint: 'Delivery regions',
              ),
              const SizedBox(height: 8),
              Text(
                'Buyers will use the contact methods tied to your seller profile.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
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
                    : const Text('Publish listing'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required field';
    }
    return null;
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(hintText: hint),
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
    required this.photo,
    required this.onTap,
    required this.onClear,
  });

  final XFile? photo;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: .2),
          ),
          color: Colors.white,
        ),
        child: photo == null
            ? const Center(
                child: Icon(
                  Icons.add_a_photo_rounded,
                  color: AppColors.primaryGreen,
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(File(photo!.path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: onClear,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
