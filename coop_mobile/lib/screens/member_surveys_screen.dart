import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'take_survey_screen.dart';

class MemberSurveysScreen extends StatefulWidget {
  final MemberModel member;

  const MemberSurveysScreen({super.key, required this.member});

  @override
  State<MemberSurveysScreen> createState() => _MemberSurveysScreenState();
}

class _MemberSurveysScreenState extends State<MemberSurveysScreen> {
  List<SurveyModel> _surveys = [];
  final Map<String, bool> _submissionStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    setState(() => _isLoading = true);
    final all = await FirebaseService.instance.getSurveys();
    final active = all.where((s) => s.isActive).toList();

    for (final s in active) {
      final done = await FirebaseService.instance.hasMemberSubmittedSurvey(s.id, widget.member.accountNumber);
      _submissionStatus[s.id] = done;
    }

    if (mounted) {
      setState(() {
        _surveys = active;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('MMM d, y h:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Surveys'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadSurveys,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSurveys,
              child: _surveys.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'No Active Surveys Available',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'There are no surveys scheduled right now. Check back later!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _surveys.length,
                      itemBuilder: (context, index) {
                        final survey = _surveys[index];
                        final isSubmitted = _submissionStatus[survey.id] == true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isSubmitted
                                            ? AppTheme.accent.withOpacity(0.12)
                                            : Colors.orange.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isSubmitted ? 'SUBMITTED' : 'OPEN FOR RESPONSES',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSubmitted ? AppTheme.accent : Colors.orange[800],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.alarm, size: 14, color: AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Closes ${_formatDate(survey.closesAt)}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  survey.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                if (survey.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    survey.description,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Text(
                                      '${survey.questions.length} question(s)',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                                    ),
                                    const Spacer(),
                                    if (isSubmitted)
                                      const Chip(
                                        avatar: Icon(Icons.check_circle, size: 16, color: AppTheme.accent),
                                        label: Text('Response Recorded'),
                                        labelStyle: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold),
                                        backgroundColor: Color(0xFFFCE7F0),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final done = await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TakeSurveyScreen(
                                                survey: survey,
                                                member: widget.member,
                                              ),
                                            ),
                                          );
                                          if (done == true) {
                                            _loadSurveys();
                                          }
                                        },
                                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                                        label: const Text('Answer Survey'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
