import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class StaffMemberFormScreen extends StatefulWidget {
  final MemberModel? member;

  const StaffMemberFormScreen({super.key, this.member});

  @override
  State<StaffMemberFormScreen> createState() => _StaffMemberFormScreenState();
}

class _StaffMemberFormScreenState extends State<StaffMemberFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _accountCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _firstNameCtrl;
  late TextEditingController _middleNameCtrl;
  late TextEditingController _extensionNameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _birthdayCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _employerCtrl;
  late TextEditingController _employerAddressCtrl;
  late TextEditingController _spouseNameCtrl;
  late TextEditingController _spouseOccupationCtrl;
  late TextEditingController _spouseEmployerCtrl;
  late TextEditingController _fatherNameCtrl;
  late TextEditingController _motherNameCtrl;
  late TextEditingController _ref1Ctrl;
  late TextEditingController _ref2Ctrl;

  late String _civilStatus;
  late List<ChildModel> _children;
  bool _isSaving = false;
  bool _isGeneratingAccount = false;

  final List<String> _civilStatusOptions = ['Single', 'Married', 'Widowed', 'Separated'];

  bool get _isEdit => widget.member != null;
  bool get _isSingle => _civilStatus == 'Single';

  @override
  void initState() {
    super.initState();
    final m = widget.member;

    _accountCtrl = TextEditingController(text: m?.accountNumber ?? '');
    _lastNameCtrl = TextEditingController(text: m?.lastName ?? '');
    _firstNameCtrl = TextEditingController(text: m?.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: m?.middleName ?? '');
    _extensionNameCtrl = TextEditingController(text: m?.extensionName ?? '');
    _addressCtrl = TextEditingController(text: m?.address ?? '');
    _contactCtrl = TextEditingController(text: m?.contactNumber ?? '');
    _birthdayCtrl = TextEditingController(text: m?.birthday ?? '');
    _occupationCtrl = TextEditingController(text: m?.occupation ?? '');
    _employerCtrl = TextEditingController(text: m?.employer ?? '');
    _employerAddressCtrl = TextEditingController(text: m?.employerAddress ?? '');
    _spouseNameCtrl = TextEditingController(text: m?.spouseName ?? '');
    _spouseOccupationCtrl = TextEditingController(text: m?.spouseOccupation ?? '');
    _spouseEmployerCtrl = TextEditingController(text: m?.spouseEmployer ?? '');
    _fatherNameCtrl = TextEditingController(text: m?.fatherName ?? '');
    _motherNameCtrl = TextEditingController(text: m?.motherName ?? '');
    _ref1Ctrl = TextEditingController(text: m?.referenceOne ?? '');
    _ref2Ctrl = TextEditingController(text: m?.referenceTwo ?? '');

    _civilStatus = m != null && _civilStatusOptions.contains(m.civilStatus)
        ? m.civilStatus
        : 'Single';

    _children = m != null
        ? List.from(m.children.map((c) => ChildModel(name: c.name, age: c.age)))
        : [];

    if (!_isEdit) {
      _generateNextAccount();
    }
  }

  Future<void> _generateNextAccount() async {
    setState(() => _isGeneratingAccount = true);
    final next = await FirebaseService.instance.generateNextAccountNumber();
    if (mounted) {
      setState(() {
        _accountCtrl.text = next;
        _isGeneratingAccount = false;
      });
    }
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _extensionNameCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    _birthdayCtrl.dispose();
    _occupationCtrl.dispose();
    _employerCtrl.dispose();
    _employerAddressCtrl.dispose();
    _spouseNameCtrl.dispose();
    _spouseOccupationCtrl.dispose();
    _spouseEmployerCtrl.dispose();
    _fatherNameCtrl.dispose();
    _motherNameCtrl.dispose();
    _ref1Ctrl.dispose();
    _ref2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 25));
    try {
      if (_birthdayCtrl.text.isNotEmpty) {
        initial = DateTime.parse(_birthdayCtrl.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _birthdayCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addChild() {
    setState(() {
      _children.add(ChildModel(name: '', age: 0));
    });
  }

  void _removeChild(int index) {
    setState(() {
      _children.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out all required fields properly.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final cleanChildren = _isSingle
        ? <ChildModel>[]
        : _children.where((c) => c.name.trim().isNotEmpty).toList();

    final accountNumber = _accountCtrl.text.trim();
    final temporaryPassword = _isEdit ? '' : accountNumber;

    final member = MemberModel(
      id: accountNumber,
      accountNumber: accountNumber,
      password: _isEdit ? '' : temporaryPassword,
      forcePasswordChange: _isEdit ? widget.member!.forcePasswordChange : true,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
      extensionName: _extensionNameCtrl.text.trim(),
      civilStatus: _civilStatus,
      address: _addressCtrl.text.trim(),
      contactNumber: _contactCtrl.text.trim(),
      birthday: _birthdayCtrl.text.trim(),
      occupation: _occupationCtrl.text.trim(),
      employer: _employerCtrl.text.trim(),
      employerAddress: _employerAddressCtrl.text.trim(),
      spouseName: _isSingle ? '' : _spouseNameCtrl.text.trim(),
      spouseOccupation: _isSingle ? '' : _spouseOccupationCtrl.text.trim(),
      spouseEmployer: _isSingle ? '' : _spouseEmployerCtrl.text.trim(),
      fatherName: _fatherNameCtrl.text.trim(),
      motherName: _motherNameCtrl.text.trim(),
      referenceOne: _ref1Ctrl.text.trim(),
      referenceTwo: _ref2Ctrl.text.trim(),
      createdAt: _isEdit ? widget.member!.createdAt : DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      children: cleanChildren,
    );

    final ok = await FirebaseService.instance.saveMember(member);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Member record updated in Firebase Realtime Database!'
                : 'Member created! Default password is $accountNumber. The member must change it upon login.',
          ),
          backgroundColor: AppTheme.accent,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save to Firebase. Please check connection.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Member Record' : 'Register New Member'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account info card
            Card(
              color: AppTheme.primary.withOpacity(0.04),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.badge, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Number',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                          Text(
                            _isGeneratingAccount ? 'Generating...' : _accountCtrl.text,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                    if (!_isEdit)
                      IconButton(
                        tooltip: 'Regenerate Account #',
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: _generateNextAccount,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 1. Personal Information
            _sectionHeader('1. Personal Details', Icons.person_outline),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameCtrl,
                            decoration: const InputDecoration(labelText: 'First name *'),
                            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameCtrl,
                            decoration: const InputDecoration(labelText: 'Last name *'),
                            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _middleNameCtrl,
                            decoration: const InputDecoration(labelText: 'Middle name'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _extensionNameCtrl,
                            decoration: const InputDecoration(labelText: 'Extension (Jr, III)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _civilStatus,
                            decoration: const InputDecoration(labelText: 'Civil status *'),
                            items: _civilStatusOptions.map((s) {
                              return DropdownMenuItem(value: s, child: Text(s));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _civilStatus = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _birthdayCtrl,
                            readOnly: true,
                            onTap: _pickBirthday,
                            decoration: const InputDecoration(
                              labelText: 'Birthday *',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Contact Information
            _sectionHeader('2. Contact & Address', Icons.home_outlined),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contactCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number (11 digits) *',
                        hintText: '09171234567',
                        prefixIcon: Icon(Icons.phone, size: 18),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return 'Required';
                        if (!RegExp(r'^\d{11}$').hasMatch(text)) {
                          return 'Must be exactly 11 digits (e.g. 09171234567)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Permanent Address *',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                      ),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Employment Details
            _sectionHeader('3. Employment Details', Icons.work_outline),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _occupationCtrl,
                      decoration: const InputDecoration(labelText: 'Occupation'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _employerCtrl,
                      decoration: const InputDecoration(labelText: 'Employer / Business Name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _employerAddressCtrl,
                      decoration: const InputDecoration(labelText: 'Employer Address'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Family Details (Toggled based on Civil Status)
            _sectionHeader('4. Family Details', Icons.family_restroom_outlined),
            if (_isSingle)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[500], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Family & children sections are omitted because civil status is "Single".',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _spouseNameCtrl,
                        decoration: const InputDecoration(labelText: 'Spouse full name'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _spouseOccupationCtrl,
                              decoration: const InputDecoration(labelText: 'Spouse occupation'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _spouseEmployerCtrl,
                              decoration: const InputDecoration(labelText: 'Spouse employer'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Children Records',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                          ),
                          TextButton.icon(
                            onPressed: _addChild,
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('Add Child', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      ..._children.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final child = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: child.name,
                                  decoration: InputDecoration(
                                    labelText: 'Child name #${idx + 1}',
                                    isDense: true,
                                  ),
                                  onChanged: (v) => child.name = v,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  initialValue: child.age > 0 ? child.age.toString() : '',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Age',
                                    isDense: true,
                                  ),
                                  onChanged: (v) => child.age = int.tryParse(v) ?? 0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: AppTheme.danger, size: 20),
                                onPressed: () => _removeChild(idx),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 5. Parents & Character References
            _sectionHeader('5. Parents & Character References', Icons.people_outline),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fatherNameCtrl,
                            decoration: const InputDecoration(labelText: "Father's full name"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _motherNameCtrl,
                            decoration: const InputDecoration(labelText: "Mother's maiden name"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ref1Ctrl,
                      decoration: const InputDecoration(labelText: 'Reference 1 (Name & Contact)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ref2Ctrl,
                      decoration: const InputDecoration(labelText: 'Reference 2 (Name & Contact)'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isEdit ? 'Update Member Record' : 'Create & Save to Firebase',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}
