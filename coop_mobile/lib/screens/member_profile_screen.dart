import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class MemberProfileScreen extends StatefulWidget {
  final MemberModel member;

  const MemberProfileScreen({super.key, required this.member});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final _formKey = GlobalKey<FormState>();

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

  final List<String> _civilStatusOptions = ['Single', 'Married', 'Widowed', 'Separated'];

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _lastNameCtrl = TextEditingController(text: m.lastName);
    _firstNameCtrl = TextEditingController(text: m.firstName);
    _middleNameCtrl = TextEditingController(text: m.middleName);
    _extensionNameCtrl = TextEditingController(text: m.extensionName);
    _addressCtrl = TextEditingController(text: m.address);
    _contactCtrl = TextEditingController(text: m.contactNumber);
    _birthdayCtrl = TextEditingController(text: m.birthday);
    _occupationCtrl = TextEditingController(text: m.occupation);
    _employerCtrl = TextEditingController(text: m.employer);
    _employerAddressCtrl = TextEditingController(text: m.employerAddress);
    _spouseNameCtrl = TextEditingController(text: m.spouseName);
    _spouseOccupationCtrl = TextEditingController(text: m.spouseOccupation);
    _spouseEmployerCtrl = TextEditingController(text: m.spouseEmployer);
    _fatherNameCtrl = TextEditingController(text: m.fatherName);
    _motherNameCtrl = TextEditingController(text: m.motherName);
    _ref1Ctrl = TextEditingController(text: m.referenceOne);
    _ref2Ctrl = TextEditingController(text: m.referenceTwo);

    _civilStatus = _civilStatusOptions.contains(m.civilStatus) ? m.civilStatus : 'Single';
    _children = List.from(m.children.map((c) => ChildModel(name: c.name, age: c.age)));
  }

  @override
  void dispose() {
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

  bool get _isSingle => _civilStatus == 'Single';

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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the form before saving.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final m = widget.member;
    m.lastName = _lastNameCtrl.text.trim();
    m.firstName = _firstNameCtrl.text.trim();
    m.middleName = _middleNameCtrl.text.trim();
    m.extensionName = _extensionNameCtrl.text.trim();
    m.civilStatus = _civilStatus;
    m.address = _addressCtrl.text.trim();
    m.contactNumber = _contactCtrl.text.trim();
    m.birthday = _birthdayCtrl.text.trim();
    m.occupation = _occupationCtrl.text.trim();
    m.employer = _employerCtrl.text.trim();
    m.employerAddress = _employerAddressCtrl.text.trim();
    m.fatherName = _fatherNameCtrl.text.trim();
    m.motherName = _motherNameCtrl.text.trim();
    m.referenceOne = _ref1Ctrl.text.trim();
    m.referenceTwo = _ref2Ctrl.text.trim();

    if (_isSingle) {
      m.spouseName = '';
      m.spouseOccupation = '';
      m.spouseEmployer = '';
      m.children = [];
    } else {
      m.spouseName = _spouseNameCtrl.text.trim();
      m.spouseOccupation = _spouseOccupationCtrl.text.trim();
      m.spouseEmployer = _spouseEmployerCtrl.text.trim();
      m.children = _children.where((c) => c.name.trim().isNotEmpty).toList();
    }

    final success = await FirebaseService.instance.saveMember(m);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully in Firebase Realtime Database!'),
          backgroundColor: AppTheme.accent,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally. Realtime sync will retry.'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Member Profile'),
        actions: [
          IconButton(
            tooltip: 'Save Profile',
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Account Number: ${widget.member.accountNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 1. PERSONAL INFORMATION
            _sectionHeader('1. Personal Information', Icons.person_outline),
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

            // 2. CONTACT INFORMATION
            _sectionHeader('2. Contact & Residence', Icons.contact_phone_outlined),
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
                        labelText: 'Contact number (11 digits) *',
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
                        labelText: 'Complete Address *',
                        prefixIcon: Icon(Icons.home_outlined, size: 18),
                      ),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. EMPLOYMENT DETAILS
            _sectionHeader('3. Employment Details', Icons.work_outline),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _occupationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Occupation',
                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _employerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Employer / Company Name',
                        prefixIcon: Icon(Icons.business_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _employerAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Employer Address',
                        prefixIcon: Icon(Icons.location_city_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. FAMILY DETAILS (Disabled if Single, matching web application!)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader('4. Family Details', Icons.family_restroom_outlined),
                if (_isSingle)
                  const Text(
                    '(Hidden for Single members)',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            if (!_isSingle) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spouse Information',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 10),
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
                      if (_children.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No children listed. Tap "Add Child" to register children.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
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
            ],

            const SizedBox(height: 16),

            // 5. PARENTS & REFERENCES
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
                            decoration: const InputDecoration(labelText: "Father's name"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _motherNameCtrl,
                            decoration: const InputDecoration(labelText: "Mother's name"),
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

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Save Profile Updates', style: TextStyle(fontSize: 16)),
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
