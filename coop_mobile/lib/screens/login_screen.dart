import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'force_password_change_screen.dart';
import 'member_dashboard_screen.dart';
import 'staff_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _memberAccountController = TextEditingController();
  final _memberPasswordController = TextEditingController();
  final _staffUsernameController = TextEditingController();
  final _staffPasswordController = TextEditingController();

  bool _obscureMemberPassword = true;
  bool _obscureStaffPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _memberAccountController.dispose();
    _memberPasswordController.dispose();
    _staffUsernameController.dispose();
    _staffPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showMemberRegistration(BuildContext loginDialogContext) async {
    final firstName = TextEditingController();
    final lastName = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final confirmPassword = TextEditingController();
    MemberModel? createdMember;
    var isSaving = false;
    String? registrationError;

    await showDialog<void>(
      context: loginDialogContext,
      builder: (registrationContext) => StatefulBuilder(
        builder: (context, setRegistrationState) => AlertDialog(
          title: const Text('Create a member account'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: firstName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name')),
              TextField(controller: lastName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Last name')),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email address')),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Create password (8+ characters)')),
              TextField(controller: confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
              if (registrationError != null) ...[
                const SizedBox(height: 10),
                Text(registrationError!, style: const TextStyle(color: AppTheme.danger)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(registrationContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: isSaving ? null : () async {
                if (password.text != confirmPassword.text) {
                  setRegistrationState(() => registrationError = 'The passwords do not match.');
                  return;
                }
                setRegistrationState(() { isSaving = true; registrationError = null; });
                final member = await FirebaseService.instance.registerMember(
                  email: email.text, firstName: firstName.text, lastName: lastName.text, password: password.text,
                );
                if (!context.mounted) return;
                if (member == null) {
                  setRegistrationState(() {
                    isSaving = false;
                    registrationError = FirebaseService.instance.lastError ?? 'Could not create your account.';
                  });
                  return;
                }
                createdMember = member;
                Navigator.pop(registrationContext);
              },
              child: Text(isSaving ? 'Creating…' : 'Create account'),
            ),
          ],
        ),
      ),
    );

    firstName.dispose(); lastName.dispose(); email.dispose(); password.dispose(); confirmPassword.dispose();
    if (!mounted || createdMember == null) return;
    if (Navigator.canPop(loginDialogContext)) Navigator.pop(loginDialogContext);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save your sign-in code'),
        content: SelectableText('Account number: ${createdMember!.accountNumber}\n\nSign in on other devices with your email address and the password you created. Save this account number for your cooperative records.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continue'))],
      ),
    );
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MemberDashboardScreen(member: createdMember!)));
  }

  Future<void> _showPasswordReset(BuildContext loginDialogContext) async {
    final email = TextEditingController();
    final entered = await showDialog<bool>(
      context: loginDialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Reset member password'),
        content: TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Registration email')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send reset email')),
        ],
      ),
    );
    if (entered == true) {
      final sent = await FirebaseService.instance.sendPasswordResetEmail(email.text);
      if (mounted && loginDialogContext.mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
          content: Text(sent ? 'Password reset instructions sent.' : FirebaseService.instance.lastError ?? 'Could not send reset instructions.'),
        ));
      }
    }
    email.dispose();
  }

  Future<void> _handleMemberLogin([BuildContext? modalContext]) async {
    final account = _memberAccountController.text.trim();
    final password = _memberPasswordController.text;

    if (account.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both account number and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final member = await FirebaseService.instance.authenticateMember(account, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (member == null) {
      setState(() => _errorMessage = FirebaseService.instance.lastError ?? 'Invalid account number or password.');
      return;
    }

    if (modalContext != null && Navigator.canPop(modalContext)) {
      Navigator.pop(modalContext);
    }

    if (member.forcePasswordChange) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ForcePasswordChangeScreen(member: member),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MemberDashboardScreen(member: member),
        ),
      );
    }
  }

  Future<void> _handleStaffLogin([BuildContext? modalContext]) async {
    final username = _staffUsernameController.text.trim();
    final password = _staffPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final staff = await FirebaseService.instance.authenticateStaff(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (staff == null) {
      setState(() => _errorMessage = FirebaseService.instance.lastError ?? 'Invalid staff credentials.');
      return;
    }

    if (modalContext != null && Navigator.canPop(modalContext)) {
      Navigator.pop(modalContext);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StaffDashboardScreen(staff: staff),
      ),
    );
  }

  void _showDatabaseSettings() {
    final urlController = TextEditingController(text: FirebaseService.instance.databaseUrl);
    String? statusMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firebase Realtime Database',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'CoopConnect project configuration',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Realtime Database URL',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: urlController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: 'https://<your-project>-default-rtdb.firebaseio.com/',
                      prefixIcon: Icon(Icons.link, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: FirebaseService.instance.isConnected
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        FirebaseService.instance.isConnected
                            ? 'Connected to Firebase'
                            : 'Sign in to verify Firebase access',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: FirebaseService.instance.isConnected
                              ? Colors.green[800]
                              : Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  if (statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      statusMessage!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            setModalState(() => statusMessage = 'Testing connection...');
                            FirebaseService.instance.setDatabaseUrl(urlController.text.trim());
                            final ok = await FirebaseService.instance.testConnection();
                            setModalState(() {
                              statusMessage = ok
                                  ? 'Connected successfully to Firebase!'
                                  : 'Sign in before testing your Firebase access.';
                            });
                          },
                          child: const Text('Test Connection'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('CoopConnect is configured for project coop-692bf.')),
                            );
                          },
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openLoginModal({int initialTab = 0}) {
    _tabController.index = initialTab;
    setState(() => _errorMessage = null);

    showDialog(
      context: context,
      barrierColor: const Color(0x666B3D59),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xEFFFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33873753),
                        blurRadius: 40,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Header
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9D4069), Color(0xFFD87D9F)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x38903957),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'CC',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CoopConnect',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF3D2733),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Member information portal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF856D7A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF856D7A), size: 20),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Tabs
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0x33B55D82), width: 1.5),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: const Color(0xFFC45E88),
                          indicatorWeight: 3,
                          labelColor: const Color(0xFFA0446B),
                          unselectedLabelColor: const Color(0xFF856D7A),
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          tabs: const [
                            Tab(text: 'Member'),
                            Tab(text: 'Staff'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE7EC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x33AE3558)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFF912044), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFF912044), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Form views
                      SizedBox(
                        height: 250,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Member Tab
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Email (new accounts) or account number (legacy accounts)',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF3D2733)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _memberAccountController,
                                    decoration: const InputDecoration(
                                      hintText: 'Use email for new accounts; account number for legacy accounts',
                                      prefixIcon: Icon(Icons.alternate_email, size: 20, color: Color(0xFF856D7A)),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Password',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF3D2733)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _memberPasswordController,
                                    obscureText: _obscureMemberPassword,
                                    decoration: InputDecoration(
                                      hintText: 'Enter password',
                                      prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF856D7A)),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureMemberPassword ? Icons.visibility_off : Icons.visibility,
                                          size: 20,
                                          color: const Color(0xFF856D7A),
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            _obscureMemberPassword = !_obscureMemberPassword;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFC86E94), Color(0xFFA74C73)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x3098405E),
                                          blurRadius: 14,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      onPressed: _isLoading ? null : () => _handleMemberLogin(dialogCtx),
                                      child: _isLoading
                                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text('Sign in as member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Create an account with your email to sign in from any device.',
                                    style: TextStyle(color: Color(0xFF856D7A), fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    onPressed: _isLoading ? null : () => _showMemberRegistration(dialogCtx),
                                    child: const Text('Create a member account'),
                                  ),
                                  TextButton(
                                    onPressed: () => _showPasswordReset(dialogCtx),
                                    child: const Text('Forgot password?'),
                                  ),
                                ],
                              ),
                            ),

                            // Staff Tab
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Username',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF3D2733)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _staffUsernameController,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter username',
                                      prefixIcon: Icon(Icons.person_outline, size: 20, color: Color(0xFF856D7A)),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Password',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF3D2733)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _staffPasswordController,
                                    obscureText: _obscureStaffPassword,
                                    decoration: InputDecoration(
                                      hintText: 'Enter password',
                                      prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF856D7A)),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureStaffPassword ? Icons.visibility_off : Icons.visibility,
                                          size: 20,
                                          color: const Color(0xFF856D7A),
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            _obscureStaffPassword = !_obscureStaffPassword;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFC86E94), Color(0xFFA74C73)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x3098405E),
                                          blurRadius: 14,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      onPressed: _isLoading ? null : () => _handleStaffLogin(dialogCtx),
                                      child: _isLoading
                                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text('Sign in as staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Staff sign-in is issued by the cooperative administrator.',
                                    style: TextStyle(color: Color(0xFF856D7A), fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 860;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF3F7),
              Color(0xFFF9DCE7),
              Color(0xFFF4C5D6),
            ],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Navigation Header (matches .home-nav)
              Container(
                height: 80,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 60 : 20,
                ),
                decoration: const BoxDecoration(
                  color: Color(0x66FFFFFF),
                  border: Border(
                    bottom: BorderSide(color: Color(0x44FFFFFF)),
                  ),
                ),
                child: Row(
                  children: [
                    // Brand Mark
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFF4A2BB), Color(0xFFB65B87)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'CC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'CoopConnect',
                      style: TextStyle(
                        color: Color(0xFF75435F),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),

                    // Member Login link
                    TextButton(
                      onPressed: () => _openLoginModal(initialTab: 0),
                      child: const Text(
                        'Member Login',
                        style: TextStyle(
                          color: Color(0xFF3D2733),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Staff Portal Pill Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDB8EB1), Color(0xFFAA6BF1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3DA369D3),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openLoginModal(initialTab: 1),
                        child: const Text(
                          'Staff Portal',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Firebase Connection',
                      icon: const Icon(Icons.cloud_queue_rounded, color: Color(0xFF75435F)),
                      onPressed: _showDatabaseSettings,
                    ),
                  ],
                ),
              ),

              // Hero Section (matches .home-main)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1140),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 30 : 20,
                      vertical: isDesktop ? 60 : 36,
                    ),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 13, child: _buildHeroContent(isDesktop)),
                              const SizedBox(width: 48),
                              Expanded(flex: 9, child: _buildHeroCard()),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeroContent(isDesktop),
                              const SizedBox(height: 36),
                              _buildHeroCard(),
                            ],
                          ),
                  ),
                ),
              ),

              // Feature row at the bottom (matches .feature-row)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1140),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 30 : 20,
                      vertical: 30,
                    ),
                    child: isDesktop
                        ? Row(
                            children: [
                              Expanded(child: _buildFeatureCard('01', 'For members', 'Review and update your information anytime.')),
                              const SizedBox(width: 24),
                              Expanded(child: _buildFeatureCard('02', 'For staff', 'Create accounts and manage cooperative records.')),
                              const SizedBox(width: 24),
                              Expanded(child: _buildFeatureCard('03', 'For everyone', 'Clear records for a stronger cooperative.')),
                            ],
                          )
                        : Column(
                            children: [
                              _buildFeatureCard('01', 'For members', 'Review and update your information anytime.'),
                              const SizedBox(height: 16),
                              _buildFeatureCard('02', 'For staff', 'Create accounts and manage cooperative records.'),
                              const SizedBox(height: 16),
                              _buildFeatureCard('03', 'For everyone', 'Clear records for a stronger cooperative.'),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroContent(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow
        const Text(
          'MULTIPURPOSE COOPERATIVE',
          style: TextStyle(
            color: Color(0xFFA54F73),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),

        // Headline with italic serif
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Your cooperative information,\n',
                style: TextStyle(
                  fontSize: isDesktop ? 54 : 34,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3D2733),
                  height: 1.08,
                  letterSpacing: -1.2,
                ),
              ),
              TextSpan(
                text: 'clear and connected.',
                style: TextStyle(
                  fontSize: isDesktop ? 54 : 34,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFA44970),
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Subtitle copy
        const Text(
          'CoopConnect makes it simple for members to keep their personal information current while giving staff a secure, organized records portal.',
          style: TextStyle(
            color: Color(0xFF765D6A),
            fontSize: 17,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        // Actions
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24,
          runSpacing: 16,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC86E94), Color(0xFFA74C73)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3098405E),
                    blurRadius: 16,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openLoginModal(initialTab: 0),
                child: const Text(
                  'Access your account',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            InkWell(
              onTap: () => _openLoginModal(initialTab: 0),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Learn more ↓',
                    style: TextStyle(
                      color: Color(0xFF6B3D59),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 44),

        // Stats
        Wrap(
          spacing: 36,
          runSpacing: 16,
          children: [
            _buildStatItem('Secure', 'Member access'),
            _buildStatItem('Simple', 'Profile updates'),
            _buildStatItem('Organized', 'Staff records'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B3D59),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF856D7A),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: const Color(0xB0FFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24873753),
            blurRadius: 55,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9D4069), Color(0xFFD87D9F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x38903957),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'CC',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'MEMBER PORTAL',
            style: TextStyle(
              color: Color(0xFFA54F73),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep your records up to date.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3D2733),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          _buildBulletItem('Update personal & contact details'),
          _buildBulletItem('Manage family information'),
          _buildBulletItem('Print your member profile'),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC86E94), Color(0xFFA74C73)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3098405E),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openLoginModal(initialTab: 0),
                child: const Text(
                  'Sign in to continue',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '✦ ',
            style: TextStyle(color: Color(0xFFB6557E), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF765D6A), fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String step, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0x75FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x88FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18873753),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFA54F73),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3D2733),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF765D6A),
            ),
          ),
        ],
      ),
    );
  }
}
