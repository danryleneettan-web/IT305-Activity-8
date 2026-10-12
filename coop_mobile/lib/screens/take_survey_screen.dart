import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class TakeSurveyScreen extends StatefulWidget {
  final SurveyModel survey;
  final MemberModel member;

  const TakeSurveyScreen({super.key, required this.survey, required this.member});

  @override
  State<TakeSurveyScreen> createState() => _TakeSurveyScreenState();
}

class _TakeSurveyScreenState extends State<TakeSurveyScreen> {
  final Map<String, String> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final q in widget.survey.questions) {
      if (q.type == 'short_answer') {
        _textControllers[q.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitSurvey() async {
    // Populate text controllers into answers
    for (final entry in _textControllers.entries) {
      _answers[entry.key] = entry.value.text.trim();
    }

    // Check required questions
    for (final q in widget.survey.questions) {
      if (q.isRequired) {
        final val = _answers[q.id]?.trim() ?? '';
        if (val.isEmpty) {
          setState(() {
            _errorMessage = 'Please complete all required questions (marked with *).';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Missing answer for Question #${widget.survey.questions.indexOf(q) + 1}.'),
              backgroundColor: AppTheme.danger,
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await FirebaseService.instance.submitSurveyResponse(
      surveyId: widget.survey.id,
      memberId: widget.member.accountNumber,
      memberName: widget.member.fullName,
      answers: _answers,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey submitted successfully! Thank you for your feedback.'),
          backgroundColor: AppTheme.accent,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _errorMessage = 'Failed to submit survey. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final survey = widget.survey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Answer Survey'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Survey Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MEMBER SURVEY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        survey.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (survey.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          survey.description,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                  ),
                ),

              // Questions List
              ...survey.questions.asMap().entries.map((entry) {
                final idx = entry.key;
                final q = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${idx + 1}. ',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${q.text}${q.isRequired ? " *" : ""}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildQuestionInput(q),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitSurvey,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Submit Survey Response', style: TextStyle(fontSize: 15)),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionInput(SurveyQuestion q) {
    switch (q.type) {
      case 'rating':
        final currentVal = _answers[q.id];
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final star = (index + 1).toString();
            final isSelected = currentVal == star;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _answers[q.id] = star;
                });
              },
              child: Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.star,
                      size: 22,
                      color: isSelected ? Colors.amber : Colors.grey[400],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      star,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );

      case 'yes_no':
        final currentVal = _answers[q.id];
        return Row(
          children: ['Yes', 'No'].map((opt) {
            final isSelected = currentVal == opt;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: Colors.grey[100],
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _answers[q.id] = opt;
                      });
                    }
                  },
                ),
              ),
            );
          }).toList(),
        );

      case 'multiple_choice':
        final currentVal = _answers[q.id];
        return Column(
          children: q.choices.map((choice) {
            final isSelected = currentVal == choice;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _answers[q.id] = choice;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          choice,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );

      case 'short_answer':
      default:
        return TextField(
          controller: _textControllers[q.id],
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your response here...',
          ),
        );
    }
  }
}
