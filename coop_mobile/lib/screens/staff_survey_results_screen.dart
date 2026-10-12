import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class StaffSurveyResultsScreen extends StatefulWidget {
  final SurveyModel survey;

  const StaffSurveyResultsScreen({super.key, required this.survey});

  @override
  State<StaffSurveyResultsScreen> createState() => _StaffSurveyResultsScreenState();
}

class _StaffSurveyResultsScreenState extends State<StaffSurveyResultsScreen> {
  List<SurveySubmission> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final subs = await FirebaseService.instance.getSurveySubmissions(widget.survey.id);
    if (mounted) {
      setState(() {
        _submissions = subs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final survey = widget.survey;
    final total = _submissions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Results'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadResults,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadResults,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Survey Header Summary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SURVEY ANALYTICS',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            survey.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.people_alt_outlined, size: 16, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '$total submitted response${total == 1 ? "" : "s"}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                              ),
                              const Spacer(),
                              Text(
                                'Status: ${survey.status.toUpperCase()}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (total == 0)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'No Responses Recorded Yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'As members take this survey in the mobile app, their answers and percentage distributions will update here in real time.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Questions Breakdown
                  ...survey.questions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final q = entry.value;

                    // Aggregate answers for question q.id
                    final Map<String, int> counts = {};
                    for (final sub in _submissions) {
                      final ans = sub.answers[q.id]?.trim() ?? '';
                      if (ans.isNotEmpty) {
                        counts[ans] = (counts[ans] ?? 0) + 1;
                      }
                    }

                    // Sort by highest count
                    final sortedEntries = counts.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${idx + 1}. ${q.text}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            if (sortedEntries.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No answers recorded yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              )
                            else
                              ...sortedEntries.map((ansEntry) {
                                final count = ansEntry.value;
                                final percent = total > 0 ? (count / total * 100).round() : 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ansEntry.key,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Text(
                                            '$count ($percent%)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: total > 0 ? count / total : 0,
                                          backgroundColor: AppTheme.border,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                                          minHeight: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
