import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'member_profile_screen.dart';
import 'member_surveys_screen.dart';
import 'profile_print_view_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  final MemberModel member;

  const MemberDashboardScreen({super.key, required this.member});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  late MemberModel _currentMember;
  int _activeSurveysCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentMember = widget.member;
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final fresh = await FirebaseService.instance.getMember(_currentMember.accountNumber);
    if (fresh != null) {
      _currentMember = fresh;
    }

    final surveys = await FirebaseService.instance.getSurveys();
    int count = 0;
    for (final s in surveys) {
      if (s.isActive) {
        final done = await FirebaseService.instance.hasMemberSubmittedSurvey(s.id, _currentMember.accountNumber);
        if (!done) count++;
      }
    }

    if (mounted) {
      setState(() {
        _activeSurveysCount = count;
        _isLoading = false;
      });
    }
  }

  void _showChangePasswordDialog() {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? err;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(err!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                    ),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password (min 8 chars)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm password'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (newPassCtrl.text.length < 8) {
                            setDialogState(() => err = 'Password must have at least 8 characters.');
                            return;
                          }
                          if (newPassCtrl.text != confirmPassCtrl.text) {
                            setDialogState(() => err = 'Passwords do not match.');
                            return;
                          }
                          setDialogState(() => saving = true);
                          final ok = await FirebaseService.instance.updateMemberPassword(
                            _currentMember.accountNumber,
                            newPassCtrl.text,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Password changed successfully.' : 'Failed to change password.'),
                                backgroundColor: ok ? AppTheme.accent : AppTheme.danger,
                              ),
                            );
                          }
                        },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('MMMM d, y').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Portal'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        _currentMember.initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACC: ${_currentMember.accountNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _currentMember.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _currentMember.occupation.isNotEmpty
                                ? _currentMember.occupation
                                : 'Cooperative Member',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Active surveys notification alert
              if (_activeSurveysCount > 0)
                Card(
                  color: const Color(0xFFFEF3C7),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberSurveysScreen(member: _currentMember),
                        ),
                      );
                      _loadDashboardData();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.poll_rounded, color: AppTheme.warning, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Survey Pending',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'You have $_activeSurveysCount pending cooperative survey(s). Your feedback matters!',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Member Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Member Overview',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Chip(
                            label: Text(_currentMember.civilStatus),
                            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _detailRow(Icons.phone_outlined, 'Contact', _currentMember.contactNumber),
                      const SizedBox(height: 12),
                      _detailRow(Icons.location_on_outlined, 'Address', _currentMember.address),
                      const SizedBox(height: 12),
                      _detailRow(Icons.cake_outlined, 'Birthday', _currentMember.birthday),
                      const SizedBox(height: 12),
                      _detailRow(Icons.business_outlined, 'Employer', _currentMember.employer.isNotEmpty ? _currentMember.employer : 'Not provided'),
                      const SizedBox(height: 12),
                      _detailRow(
                        Icons.child_care_outlined,
                        'Children',
                        _currentMember.children.isEmpty
                            ? 'None registered'
                            : '${_currentMember.children.length} registered (${_currentMember.children.map((c) => "${c.name} (${c.age}yo)").join(", ")})',
                      ),
                      const SizedBox(height: 12),
                      _detailRow(Icons.update_outlined, 'Last Updated', _formatDate(_currentMember.updatedAt)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quick Action Tiles
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.edit_note_rounded,
                      title: 'Update Profile',
                      subtitle: 'Edit details & family',
                      color: AppTheme.primary,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberProfileScreen(member: _currentMember),
                          ),
                        );
                        _loadDashboardData();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.assignment_outlined,
                      title: 'Surveys',
                      subtitle: '$_activeSurveysCount active survey(s)',
                      color: AppTheme.accent,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberSurveysScreen(member: _currentMember),
                          ),
                        );
                        _loadDashboardData();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.print_outlined,
                      title: 'Print Profile',
                      subtitle: 'Summary report view',
                      color: Colors.blueGrey,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePrintViewScreen(member: _currentMember),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.lock_reset,
                      title: 'Password',
                      subtitle: 'Change your security key',
                      color: Colors.deepPurple,
                      onTap: _showChangePasswordDialog,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '—',
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
