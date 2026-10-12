import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ProfilePrintViewScreen extends StatelessWidget {
  final MemberModel member;

  const ProfilePrintViewScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Member Profile Summary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header logo / title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CC',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CoopConnect Cooperative',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Official Member Record Card',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 30),

              // Account & Name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ACCOUNT NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        member.accountNumber,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  Chip(
                    label: Text(member.civilStatus.toUpperCase()),
                    labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                member.fullName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                member.occupation.isNotEmpty ? member.occupation : 'Member',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 20),

              // Contact & Personal
              _sectionTitle('Contact & Personal Details'),
              _infoRow('Address', member.address),
              _infoRow('Contact Number', member.contactNumber),
              _infoRow('Birthday', member.birthday),
              _infoRow('Occupation', member.occupation),
              _infoRow('Employer', member.employer),
              _infoRow('Employer Address', member.employerAddress),

              const SizedBox(height: 20),

              // Family Information
              _sectionTitle('Family Information'),
              _infoRow('Spouse', member.spouseName),
              _infoRow('Spouse Occupation', member.spouseOccupation),
              _infoRow('Father', member.fatherName),
              _infoRow('Mother', member.motherName),

              const SizedBox(height: 20),

              // Children Information
              _sectionTitle('Registered Children'),
              if (member.children.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('None recorded', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                )
              else
                ...member.children.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${c.name} — ${c.age} years old',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // References
              _sectionTitle('Character References'),
              _infoRow('Reference 1', member.referenceOne),
              _infoRow('Reference 2', member.referenceTwo),

              const Divider(height: 36),

              Center(
                child: Text(
                  'Record generated via CoopConnect Mobile & Firebase Realtime Database',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
