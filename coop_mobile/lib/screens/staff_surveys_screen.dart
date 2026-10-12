import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'staff_survey_form_screen.dart';
import 'staff_survey_results_screen.dart';

class StaffSurveysScreen extends StatefulWidget {
  const StaffSurveysScreen({super.key});

  @override
  State<StaffSurveysScreen> createState() => _StaffSurveysScreenState();
}

class _StaffSurveysScreenState extends State<StaffSurveysScreen> {
  List<SurveyModel> _surveys = [];
  final Map<String, int> _respondentsCount = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    setState(() => _isLoading = true);
    final list = await FirebaseService.instance.getSurveys();

    for (final s in list) {
      final subs = await FirebaseService.instance.getSurveySubmissions(s.id);
      _respondentsCount[s.id] = subs.length;
    }

    if (mounted) {
      setState(() {
        _surveys = list;
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

  Future<void> _deactivateSurvey(SurveyModel survey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Survey'),
        content: Text('Are you sure you want to deactivate "${survey.title}"? Members will no longer be able to submit responses.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseService.instance.deactivateSurvey(survey.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Survey deactivated.'), backgroundColor: AppTheme.accent),
        );
        _loadSurveys();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadSurveys,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Survey'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StaffSurveyFormScreen()),
          );
          _loadSurveys();
        },
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
                            Icon(Icons.assignment_outlined, size: 56, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'No Surveys Found',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap "New Survey" to create your first cooperative survey.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _surveys.length,
                      itemBuilder: (context, index) {
                        final survey = _surveys[index];
                        final respondents = _respondentsCount[survey.id] ?? 0;
                        final isActive = survey.status == 'active';

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
                                        color: isActive
                                            ? AppTheme.accent.withOpacity(0.12)
                                            : Colors.grey.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        survey.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isActive ? AppTheme.accent : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$respondents response${respondents == 1 ? "" : "s"}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  survey.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                if (survey.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    survey.description,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  'Schedule: ${_formatDate(survey.opensAt)} — ${_formatDate(survey.closesAt)}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => StaffSurveyResultsScreen(survey: survey),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.bar_chart, size: 16),
                                      label: const Text('View Results'),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isActive)
                                      TextButton(
                                        style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                                        onPressed: () => _deactivateSurvey(survey),
                                        child: const Text('Deactivate'),
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
