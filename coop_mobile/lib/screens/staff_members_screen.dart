import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'profile_print_view_screen.dart';
import 'staff_member_form_screen.dart';

class StaffMembersScreen extends StatefulWidget {
  final bool recentOnly;

  const StaffMembersScreen({super.key, this.recentOnly = false});

  @override
  State<StaffMembersScreen> createState() => _StaffMembersScreenState();
}

class _StaffMembersScreenState extends State<StaffMembersScreen> {
  final _searchController = TextEditingController();
  List<MemberModel> _members = [];
  bool _isLoading = true;
  late bool _filterRecent;

  @override
  void initState() {
    super.initState();
    _filterRecent = widget.recentOnly;
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final list = await FirebaseService.instance.getMembers(
      query: _searchController.text.trim(),
      recentOnly: _filterRecent,
    );
    if (mounted) {
      setState(() {
        _members = list;
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

  Future<void> _confirmResetPassword(MemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text(
          'Reset password for ${member.fullName} (${member.accountNumber})?\n\nThe password will be reset to the account number, and the member will be required to change it on their next login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await FirebaseService.instance.resetMemberPassword(member.accountNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Password reset to account number (${member.accountNumber}).'
                  : 'Failed to reset password.',
            ),
            backgroundColor: ok ? AppTheme.accent : AppTheme.danger,
          ),
        );
        _loadMembers();
      }
    }
  }

  Future<void> _confirmDeleteMember(MemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member Record'),
        content: Text(
          'Are you sure you want to permanently delete ${member.fullName} (${member.accountNumber}) from Firebase Realtime Database? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await FirebaseService.instance.deleteMember(member.accountNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Member record deleted from Firebase.' : 'Failed to delete member.',
            ),
            backgroundColor: ok ? AppTheme.accent : AppTheme.danger,
          ),
        );
        _loadMembers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Directory'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadMembers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Member'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StaffMemberFormScreen()),
          );
          _loadMembers();
        },
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search account number or member name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadMembers();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    _loadMembers();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Updated This Week'),
                      selected: _filterRecent,
                      onSelected: (val) {
                        setState(() => _filterRecent = val);
                        _loadMembers();
                      },
                    ),
                    const Spacer(),
                    Text(
                      '${_members.length} record(s)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Member List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadMembers,
                    child: _members.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_search_outlined, size: 56, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No Member Records Found',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Try adjusting your search terms or add a new member.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              final member = _members[index];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                                            child: Text(
                                              member.initials,
                                              style: const TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  member.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${member.accountNumber} • ${member.contactNumber}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (action) async {
                                              if (action == 'edit') {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => StaffMemberFormScreen(member: member),
                                                  ),
                                                );
                                                _loadMembers();
                                              } else if (action == 'print') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ProfilePrintViewScreen(member: member),
                                                  ),
                                                );
                                              } else if (action == 'reset') {
                                                _confirmResetPassword(member);
                                              } else if (action == 'delete') {
                                                _confirmDeleteMember(member);
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Edit Member'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'print',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.print_outlined, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Print / View Profile'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'reset',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.lock_reset, size: 18, color: AppTheme.warning),
                                                    SizedBox(width: 8),
                                                    Text('Reset Password', style: TextStyle(color: AppTheme.warning)),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                                    SizedBox(width: 8),
                                                    Text('Delete Record', style: TextStyle(color: AppTheme.danger)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            member.occupation.isNotEmpty
                                                ? member.occupation
                                                : 'No occupation listed',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                          Text(
                                            'Updated: ${_formatDate(member.updatedAt)}',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
          ),
        ],
      ),
    );
  }
}
