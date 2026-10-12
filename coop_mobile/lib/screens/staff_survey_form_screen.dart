import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class StaffSurveyFormScreen extends StatefulWidget {
  final SurveyModel? survey;

  const StaffSurveyFormScreen({super.key, this.survey});

  @override
  State<StaffSurveyFormScreen> createState() => _StaffSurveyFormScreenState();
}

class _StaffSurveyFormScreenState extends State<StaffSurveyFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _opensAtCtrl;
  late TextEditingController _closesAtCtrl;

  String _status = 'active';
  List<Map<String, dynamic>> _questions = [];
  bool _isSaving = false;

  final List<String> _statusOptions = ['draft', 'active', 'inactive'];
  final List<String> _questionTypes = ['multiple_choice', 'yes_no', 'rating', 'short_answer'];

  @override
  void initState() {
    super.initState();
    final s = widget.survey;
    _titleCtrl = TextEditingController(text: s?.title ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');

    final now = DateTime.now();
    final nextMonth = now.add(const Duration(days: 30));

    _opensAtCtrl = TextEditingController(
      text: s?.opensAt.isNotEmpty == true ? s!.opensAt : DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
    );
    _closesAtCtrl = TextEditingController(
      text: s?.closesAt.isNotEmpty == true ? s!.closesAt : DateFormat('yyyy-MM-dd HH:mm:ss').format(nextMonth),
    );

    _status = s?.status ?? 'active';

    if (s != null && s.questions.isNotEmpty) {
      _questions = s.questions.map((q) {
        return {
          'id': q.id,
          'textCtrl': TextEditingController(text: q.text),
          'type': q.type,
          'isRequired': q.isRequired,
          'choicesCtrl': TextEditingController(text: q.choices.join('\n')),
        };
      }).toList();
    } else {
      // Add one default question to start
      _addQuestion();
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'id': 'q_${DateTime.now().millisecondsSinceEpoch}',
        'textCtrl': TextEditingController(),
        'type': 'multiple_choice',
        'isRequired': true,
        'choicesCtrl': TextEditingController(text: 'Option 1\nOption 2'),
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      final removed = _questions.removeAt(index);
      (removed['textCtrl'] as TextEditingController).dispose();
      (removed['choicesCtrl'] as TextEditingController).dispose();
    });
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 8, minute: 0),
      );

      if (pickedTime != null) {
        final dt = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          controller.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
        });
      }
    }
  }

  Future<void> _saveSurvey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question.'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _isSaving = true);

    final questionsList = <SurveyQuestion>[];
    for (int i = 0; i < _questions.length; i++) {
      final item = _questions[i];
      final text = (item['textCtrl'] as TextEditingController).text.trim();
      final type = item['type'] as String;
      final isRequired = item['isRequired'] as bool;
      final choicesStr = (item['choicesCtrl'] as TextEditingController).text;

      final choices = choicesStr
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      questionsList.add(
        SurveyQuestion(
          id: item['id'] as String,
          order: i + 1,
          text: text,
          type: type,
          isRequired: isRequired,
          choices: choices,
        ),
      );
    }

    final survey = SurveyModel(
      id: widget.survey?.id ?? 'survey_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      status: _status,
      opensAt: _opensAtCtrl.text.trim(),
      closesAt: _closesAtCtrl.text.trim(),
      createdBy: 'admin',
      createdAt: widget.survey?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      questions: questionsList,
    );

    final ok = await FirebaseService.instance.saveSurvey(survey);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey saved to Firebase!'), backgroundColor: AppTheme.accent),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save survey. Check connection.'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _opensAtCtrl.dispose();
    _closesAtCtrl.dispose();
    for (final item in _questions) {
      (item['textCtrl'] as TextEditingController).dispose();
      (item['choicesCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  String _formatTypeLabel(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'yes_no':
        return 'Yes / No';
      case 'rating':
        return 'Rating Scale (1-5)';
      case 'short_answer':
        return 'Short Answer';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey != null ? 'Edit Survey' : 'Create Survey'),
        actions: [
          IconButton(
            tooltip: 'Save Survey',
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveSurvey,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Survey Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Survey Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Survey Title *'),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: _statusOptions.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s.toUpperCase()));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _opensAtCtrl,
                            readOnly: true,
                            onTap: () => _pickDateTime(_opensAtCtrl),
                            decoration: const InputDecoration(
                              labelText: 'Opens At *',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _closesAtCtrl,
                            readOnly: true,
                            onTap: () => _pickDateTime(_closesAtCtrl),
                            decoration: const InputDecoration(
                              labelText: 'Closes At *',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description / Instructions'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Questions Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SURVEY QUESTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Question'),
                ),
              ],
            ),

            const SizedBox(height: 6),

            ..._questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              final type = q['type'] as String;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Question', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
                            onPressed: () => _removeQuestion(idx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: q['textCtrl'] as TextEditingController,
                        decoration: const InputDecoration(labelText: 'Question text *'),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: type,
                              decoration: const InputDecoration(labelText: 'Type'),
                              items: _questionTypes.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(_formatTypeLabel(t), style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => q['type'] = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: q['isRequired'] as bool,
                                onChanged: (val) {
                                  setState(() => q['isRequired'] = val ?? true);
                                },
                              ),
                              const Text('Required', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      if (type == 'multiple_choice') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: q['choicesCtrl'] as TextEditingController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Choices (one per line) *',
                            hintText: 'Option 1\nOption 2\nOption 3',
                          ),
                          validator: (v) {
                            if (type == 'multiple_choice' && (v?.trim().isEmpty ?? true)) {
                              return 'Provide at least one choice per line';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSurvey,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Save Survey to Firebase', style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
