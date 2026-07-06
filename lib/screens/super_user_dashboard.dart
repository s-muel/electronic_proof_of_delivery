import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user_model.dart';
import '../models/smtp_settings.dart';
import '../models/waybill_model.dart';
import '../services/app_user_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/settings_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
import 'edit_waybill_screen.dart';
import 'login_screen.dart';
import 'waybill_details_screen.dart';

class SuperUserDashboard extends StatefulWidget {
  const SuperUserDashboard({super.key});

  @override
  State<SuperUserDashboard> createState() => _SuperUserDashboardState();
}

class _SuperUserDashboardState extends State<SuperUserDashboard> {
  static const Color _background = Color(0xFFFCF8FF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _surfaceContainer = Color(0xFFEFEAFF);
  static const Color _surfaceLow = Color(0xFFF6F2FF);
  static const Color _outline = Color(0xFFC9C4D7);
  static const Color _primary = Color(0xFF5E3BDB);
  static const Color _onSurface = Color(0xFF1A1A2A);
  static const Color _onSurfaceVariant = Color(0xFF5E5A6B);
  static const int _waybillItemsPerPage = 25;

  final userSearchController = TextEditingController();
  final waybillSearchController = TextEditingController();
  List<AppUserModel> users = [];
  List<WaybillModel> waybills = [];
  String? selectedPage;
  String? openingPage;
  int _waybillCurrentPage = 0;
  bool isLoading = true;
  bool isRebuildingStats = false;

  @override
  void initState() {
    super.initState();
    loadAdminData();
  }

  @override
  void dispose() {
    userSearchController.dispose();
    waybillSearchController.dispose();
    super.dispose();
  }

  Future<void> loadAdminData() async {
    setState(() => isLoading = true);

    var loadedUsers = <AppUserModel>[];
    var loadedWaybills = WaybillService.getAllWaybills(includeDeleted: true);

    if (shouldUseFirestoreData) {
      try {
        loadedUsers = await AppUserService.getAllUsers();
        loadedWaybills = await FirestoreWaybillService.getAllWaybills(
          includeDeleted: true,
        );
        await WaybillService.replaceCachedWaybills(loadedWaybills);
      } catch (_) {
        loadedWaybills = WaybillService.getAllWaybills(includeDeleted: true);
      }
    }

    if (!mounted) return;

    setState(() {
      users = loadedUsers;
      waybills = loadedWaybills;
      _waybillCurrentPage = 0;
      isLoading = false;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuthService.signOut();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _openWaybill(WaybillModel waybill) async {
    final index = WaybillService.getIndexByWaybillNumber(waybill.waybillNumber);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaybillDetailsScreen(waybill: waybill, index: index),
      ),
    );

    await loadAdminData();
  }

  Future<void> _editWaybill(WaybillModel waybill) async {
    final index = WaybillService.getIndexByWaybillNumber(waybill.waybillNumber);

    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find this waybill record')),
      );
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditWaybillScreen(waybill: waybill, index: index),
      ),
    );

    if (updated == true) {
      await loadAdminData();
    }
  }

  Future<void> _toggleWaybillDeleted(WaybillModel waybill) async {
    final confirmed = await _confirm(
      title: waybill.isDeleted ? 'Restore Waybill' : 'Delete Waybill',
      message: waybill.isDeleted
          ? 'Restore ${waybill.waybillNumber} so it appears in normal lists again?'
          : 'Delete ${waybill.waybillNumber}? This will hide it from normal waybill lists, but it can still be restored here.',
    );

    if (!confirmed) return;

    final currentUser = await FirebaseAuthService.getCurrentUserProfile();
    final deletedBy =
        currentUser?.email ??
        FirebaseAuthService.currentFirebaseUser?.email ??
        '';

    if (waybill.isDeleted) {
      await WaybillService.restoreWaybillByNumber(waybill.waybillNumber);
      if (shouldUseFirestoreData) {
        await FirestoreWaybillService.restoreWaybill(waybill);
      }
    } else {
      await WaybillService.softDeleteWaybillByNumber(
        waybillNumber: waybill.waybillNumber,
        deletedBy: deletedBy,
      );
      if (shouldUseFirestoreData) {
        await FirestoreWaybillService.softDeleteWaybill(
          waybill: waybill,
          deletedBy: deletedBy,
        );
      }
    }

    await loadAdminData();
  }

  Future<void> _toggleUserActive(AppUserModel user) async {
    final confirmed = await _confirm(
      title: user.isActive ? 'Deactivate User' : 'Reactivate User',
      message: user.isActive
          ? 'Deactivate ${user.fullName}? They will no longer be allowed into the app.'
          : 'Reactivate ${user.fullName}?',
    );

    if (!confirmed) return;

    await AppUserService.setUserActive(user: user, isActive: !user.isActive);
    await loadAdminData();
  }

  Future<void> _sendPasswordReset(AppUserModel user) async {
    await AppUserService.sendPasswordReset(user.email);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset sent to ${user.email}')),
    );
  }

  Future<void> _showAddUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var selectedRole = 'officer';
    var selectedDepartment = 'Transport';
    var isSaving = false;
    var obscurePassword = true;
    var obscureConfirmPassword = true;

    final userCreated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add User'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Email is required';
                            }
                            if (!email.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'officer',
                              child: Text('Officer'),
                            ),
                            DropdownMenuItem(
                              value: 'driver',
                              child: Text('Driver'),
                            ),
                            DropdownMenuItem(
                              value: 'accounts',
                              child: Text('Accounts'),
                            ),
                            DropdownMenuItem(
                              value: 'management',
                              child: Text('Management'),
                            ),
                            DropdownMenuItem(
                              value: 'manager',
                              child: Text('Manager'),
                            ),
                            DropdownMenuItem(
                              value: 'super_user',
                              child: Text('Super User'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedRole = value);
                            }
                          },
                        ),
                        if (selectedRole != 'management') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedDepartment,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Transport',
                                child: Text('Transport'),
                              ),
                              DropdownMenuItem(
                                value: 'CNF',
                                child: Text('CNF'),
                              ),
                              DropdownMenuItem(
                                value: 'Shipping',
                                child: Text('Shipping'),
                              ),
                              DropdownMenuItem(
                                value: 'HeavyLift',
                                child: Text('HeavyLift'),
                              ),
                              DropdownMenuItem(
                                value: 'QHSSE',
                                child: Text('QHSSE'),
                              ),
                              DropdownMenuItem(
                                value: 'Accounts',
                                child: Text('Accounts'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(
                                  () => selectedDepartment = value,
                                );
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Temporary Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                );
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Use at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setDialogState(
                                  () => obscureConfirmPassword =
                                      !obscureConfirmPassword,
                                );
                              },
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Confirm password is required';
                            }
                            if (value != passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);

                          try {
                            await AppUserService.createUser(
                              fullName: fullNameController.text,
                              email: emailController.text,
                              password: passwordController.text,
                              role: selectedRole,
                              department: selectedRole == 'management'
                                  ? ''
                                  : selectedDepartment,
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext, true);
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Could not add user: $error'),
                              ),
                            );
                            setDialogState(() => isSaving = false);
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(isSaving ? 'Saving...' : 'Add User'),
                ),
              ],
            );
          },
        );
      },
    );

    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    if (userCreated == true) {
      await loadAdminData();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User added successfully')));
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _copyBackup() async {
    final backup = {
      'generatedAt': DateTime.now().toIso8601String(),
      'waybills': waybills.map((waybill) => waybill.toFirestoreMap()).toList(),
      'users': users.map((user) => user.toMap()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(ClipboardData(text: encoder.convert(backup)));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup JSON copied to clipboard')),
    );
  }

  Future<void> _rebuildWaybillStats() async {
    if (isRebuildingStats) return;

    setState(() => isRebuildingStats = true);

    try {
      final stats = await FirestoreWaybillService.rebuildWaybillStats();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waybill stats rebuilt: ${stats.total} total waybills'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not rebuild stats: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => isRebuildingStats = false);
      }
    }
  }

  Future<void> _showSmtpSettingsDialog() async {
    final settingsService = SettingsService();
    try {
      await settingsService.refreshSmtpSettingsFromFirestore();
    } catch (_) {
      // If Firestore is unavailable, the dialog uses locally cached settings.
    }
    final currentSettings = await settingsService.loadSmtpSettings();

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final hostController = TextEditingController(
      text: currentSettings.smtpHost,
    );
    final portController = TextEditingController(
      text: currentSettings.smtpPort.toString(),
    );
    final senderEmailController = TextEditingController(
      text: currentSettings.senderEmail,
    );
    final senderPasswordController = TextEditingController(
      text: currentSettings.senderPassword,
    );
    final senderNameController = TextEditingController(
      text: currentSettings.senderName,
    );
    var smtpSsl = currentSettings.smtpSsl;
    var obscurePassword = true;
    var isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('SMTP Email Settings'),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: hostController,
                          decoration: const InputDecoration(
                            labelText: 'SMTP Host',
                            border: OutlineInputBorder(),
                          ),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'SMTP Port',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final port = int.tryParse(value?.trim() ?? '');
                            if (port == null || port <= 0) {
                              return 'Enter a valid port';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: smtpSsl,
                          title: const Text('Use SSL'),
                          onChanged: (value) {
                            setDialogState(() => smtpSsl = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: senderEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Sender Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Sender email is required';
                            }
                            if (!email.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: senderPasswordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Sender Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                );
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: senderNameController,
                          decoration: const InputDecoration(
                            labelText: 'Sender Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: _requiredValidator,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);
                          try {
                            await settingsService.saveSmtpSettings(
                              SmtpSettings(
                                smtpHost: hostController.text,
                                smtpPort: int.parse(portController.text.trim()),
                                smtpSsl: smtpSsl,
                                ignoreBadCertificate: true,
                                senderEmail: senderEmailController.text,
                                senderPassword: senderPasswordController.text,
                                senderName: senderNameController.text,
                              ),
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext, true);
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not save SMTP settings: $error',
                                ),
                              ),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'Saving...' : 'Save Settings'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SMTP settings saved')));
    }
  }

  Future<void> _openSuperUserPage(String page) async {
    if (openingPage != null) return;

    setState(() => openingPage = page);
    await Future<void>.delayed(const Duration(milliseconds: 160));

    if (!mounted) return;

    setState(() {
      selectedPage = page;
      openingPage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeUsers = users.where((user) => user.isActive).length;
    final deletedWaybills = waybills
        .where((waybill) => waybill.isDeleted)
        .length;
    final activeWaybills = waybills.length - deletedWaybills;

    Widget body;
    if (selectedPage == 'users') {
      body = _buildUsersTab(activeUsers);
    } else if (selectedPage == 'waybills') {
      body = _buildWaybillsTab(deletedWaybills);
    } else if (selectedPage == 'backup') {
      body = _buildBackupTab();
    } else {
      body = _buildAdminHome(
        activeUsers: activeUsers,
        activeWaybills: activeWaybills,
        deletedWaybills: deletedWaybills,
      );
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background.withValues(alpha: 0.92),
        foregroundColor: _onSurface,
        elevation: 0,
        surfaceTintColor: _background,
        leading: selectedPage == null
            ? null
            : IconButton(
                onPressed: () => setState(() => selectedPage = null),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
        title: Text(
          _superUserPageTitle(),
          style: const TextStyle(
            color: _onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loadAdminData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: body,
    );
  }

  String _superUserPageTitle() {
    switch (selectedPage) {
      case 'users':
        return 'User Management';
      case 'waybills':
        return 'Waybill Management';
      case 'backup':
        return 'Backup';
      default:
        return 'Super User Dashboard';
    }
  }

  Widget _buildAdminHome({
    required int activeUsers,
    required int activeWaybills,
    required int deletedWaybills,
  }) {
    return RefreshIndicator(
      onRefresh: loadAdminData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _superUserHero(
            activeUsers: activeUsers,
            activeWaybills: activeWaybills,
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final actionCards = [
                _adminPageCard(
                  title: 'Users',
                  subtitle: isLoading
                      ? 'Loading users...'
                      : '$activeUsers active users',
                  badge: isLoading ? 'Please wait' : '${users.length} total',
                  icon: Icons.people,
                  color: _primary,
                  isOpening: openingPage == 'users',
                  onTap: () => _openSuperUserPage('users'),
                ),
                _adminPageCard(
                  title: 'Waybills',
                  subtitle: isLoading
                      ? 'Loading waybills...'
                      : '$activeWaybills active',
                  badge: isLoading ? 'Please wait' : '$deletedWaybills deleted',
                  icon: Icons.local_shipping,
                  color: const Color(0xFF4648D4),
                  isOpening: openingPage == 'waybills',
                  onTap: () => _openSuperUserPage('waybills'),
                ),
                _adminPageCard(
                  title: 'Database Backup',
                  subtitle: 'Generate a full JSON backup',
                  badge: 'Users + waybills',
                  icon: Icons.backup,
                  color: const Color(0xFF5E5D69),
                  isWideCard: true,
                  isOpening: openingPage == 'backup',
                  onTap: () => _openSuperUserPage('backup'),
                ),
              ];

              if (!isWide) {
                return Column(
                  children: [
                    for (final card in actionCards) ...[
                      card,
                      const SizedBox(height: 14),
                    ],
                    _systemIntegrityPanel(
                      activeUsers: activeUsers,
                      activeWaybills: activeWaybills,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: actionCards[0]),
                            const SizedBox(width: 14),
                            Expanded(child: actionCards[1]),
                          ],
                        ),
                        const SizedBox(height: 14),
                        actionCards[2],
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _systemIntegrityPanel(
                      activeUsers: activeUsers,
                      activeWaybills: activeWaybills,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _superUserHero({
    required int activeUsers,
    required int activeWaybills,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Overview',
          style: TextStyle(
            color: _onSurface,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isLoading
              ? 'BAJ E-POD control center active - loading latest data...'
              : 'BAJ E-POD control center active - $activeUsers users - $activeWaybills active waybills',
          style: const TextStyle(color: _onSurfaceVariant, fontSize: 14),
        ),
      ],
    );
  }

  Widget _adminPageCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isWideCard = false,
    bool isOpening = false,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isOpening ? null : onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: isWideCard ? 104 : 96),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outline.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _softBadge(subtitle, color),
                        _softBadge(badge, _onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
              if (isOpening)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: color,
                  ),
                )
              else
                Icon(Icons.chevron_right, color: _outline, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _softBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _systemIntegrityPanel({
    required int activeUsers,
    required int activeWaybills,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 238),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _outline.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CURRENT STATUS',
                style: TextStyle(
                  color: _primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'System Integrity',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLoading
                    ? 'Loading latest users and waybills...'
                    : 'Users, waybills, and backup tools are ready.',
                style: TextStyle(
                  color: _onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 22),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceContainer.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Optimal',
                    style: TextStyle(
                      color: _onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _miniMetric('Users', isLoading ? '--' : activeUsers.toString()),
                const SizedBox(width: 12),
                _miniMetric(
                  'Waybills',
                  isLoading ? '--' : activeWaybills.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: _onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildUsersTab(int activeUsers) {
    final filteredUsers = _filteredUsers();
    final usersByRole = _groupUsersByRole(filteredUsers);

    return RefreshIndicator(
      onRefresh: loadAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryHeader(
            title: 'User Management',
            subtitle: isLoading
                ? 'Loading users...'
                : '$activeUsers active of ${users.length} total users',
            icon: Icons.admin_panel_settings,
            action: FilledButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
            ),
          ),
          const SizedBox(height: 12),
          _buildUserSearchBox(),
          const SizedBox(height: 12),
          if (isLoading)
            _loadingDataCard('Loading users...')
          else if (users.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No users found.'),
              ),
            )
          else if (filteredUsers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No users match your search.'),
              ),
            )
          else
            for (final entry in usersByRole.entries)
              _buildRoleUserSection(
                roleLabel: entry.key,
                roleUsers: entry.value,
              ),
        ],
      ),
    );
  }

  Widget _buildUserSearchBox() {
    return TextField(
      controller: userSearchController,
      onChanged: (_) => setState(() => _waybillCurrentPage = 0),
      decoration: InputDecoration(
        hintText: 'Search users by name, email or role',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: userSearchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  userSearchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _outline.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _outline.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }

  List<AppUserModel> _filteredUsers() {
    final searchText = userSearchController.text.trim().toLowerCase();
    if (searchText.isEmpty) return users;

    return users.where((user) {
      final displayName = user.fullName.isEmpty ? user.email : user.fullName;
      final roleLabel = _roleLabel(user.role);

      return displayName.toLowerCase().contains(searchText) ||
          user.email.toLowerCase().contains(searchText) ||
          roleLabel.toLowerCase().contains(searchText) ||
          user.role.toLowerCase().contains(searchText) ||
          user.department.toLowerCase().contains(searchText);
    }).toList();
  }

  Map<String, List<AppUserModel>> _groupUsersByRole(
    List<AppUserModel> sourceUsers,
  ) {
    final groupedUsers = <String, List<AppUserModel>>{};
    const roleOrder = [
      'Super User',
      'Officer',
      'Driver',
      'Accounts',
      'Management',
      'Manager',
    ];

    for (final role in roleOrder) {
      groupedUsers[role] = [];
    }

    for (final user in sourceUsers) {
      final label = _roleLabel(user.role);
      groupedUsers.putIfAbsent(label, () => []);
      groupedUsers[label]!.add(user);
    }

    groupedUsers.removeWhere((_, roleUsers) => roleUsers.isEmpty);

    for (final roleUsers in groupedUsers.values) {
      roleUsers.sort((a, b) {
        final aName = a.fullName.isEmpty ? a.email : a.fullName;
        final bName = b.fullName.isEmpty ? b.email : b.fullName;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });
    }

    return groupedUsers;
  }

  Widget _buildRoleUserSection({
    required String roleLabel,
    required List<AppUserModel> roleUsers,
  }) {
    final activeCount = roleUsers.where((user) => user.isActive).length;

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: CircleAvatar(child: Icon(_roleIcon(roleLabel))),
        title: Text(
          roleLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$activeCount active of ${roleUsers.length} users'),
        children: [for (final user in roleUsers) _buildUserTile(user)],
      ),
    );
  }

  Widget _buildUserTile(AppUserModel user) {
    final detailLines = <String>[
      user.email,
      "Status: ${user.isActive ? 'Active' : 'Inactive'}",
      if (user.department.trim().isNotEmpty)
        "Department: ${user.department.trim()}",
      if (user.tempPass.trim().isNotEmpty) "Temp Pass: ${user.tempPass.trim()}",
    ];

    return ListTile(
      leading: CircleAvatar(
        child: Icon(user.isActive ? Icons.person : Icons.person_off),
      ),
      title: Text(user.fullName.isEmpty ? user.email : user.fullName),
      subtitle: Text(detailLines.join('\n')),
      isThreeLine: detailLines.length > 2,
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            onPressed: () => _sendPasswordReset(user),
            icon: const Icon(Icons.lock_reset),
            tooltip: 'Send Password Reset',
          ),
          IconButton(
            onPressed: () => _toggleUserActive(user),
            icon: Icon(user.isActive ? Icons.block : Icons.check_circle),
            tooltip: user.isActive ? 'Deactivate' : 'Reactivate',
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(String roleLabel) {
    switch (roleLabel) {
      case 'Super User':
        return Icons.admin_panel_settings;
      case 'Officer':
        return Icons.assignment_ind;
      case 'Driver':
        return Icons.local_shipping;
      case 'Accounts':
        return Icons.receipt_long;
      case 'Management':
        return Icons.insights;
      case 'Manager':
        return Icons.manage_accounts;
      default:
        return Icons.people;
    }
  }

  Widget _buildWaybillsTab(int deletedWaybills) {
    final filteredWaybills = _filteredWaybills();
    final totalPages = filteredWaybills.isEmpty
        ? 1
        : ((filteredWaybills.length - 1) ~/ _waybillItemsPerPage) + 1;

    if (_waybillCurrentPage >= totalPages) {
      _waybillCurrentPage = totalPages - 1;
    }

    final pageStart = _waybillCurrentPage * _waybillItemsPerPage;
    final pageEnd = (pageStart + _waybillItemsPerPage).clamp(
      0,
      filteredWaybills.length,
    );
    final visibleWaybills = filteredWaybills.sublist(pageStart, pageEnd);
    final shouldPaginate = filteredWaybills.length > _waybillItemsPerPage;

    return RefreshIndicator(
      onRefresh: loadAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryHeader(
            title: 'Waybill Management',
            subtitle: isLoading
                ? 'Loading waybills...'
                : '${waybills.length - deletedWaybills} active, $deletedWaybills deleted',
            icon: Icons.receipt_long,
          ),
          const SizedBox(height: 12),
          _buildWaybillSearchBox(),
          const SizedBox(height: 12),
          if (isLoading)
            _loadingDataCard('Loading waybills...')
          else if (waybills.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No waybills found.'),
              ),
            )
          else if (filteredWaybills.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No waybills match your search.'),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 820;
                return Column(
                  children: [
                    isWide
                        ? _buildWaybillTable(visibleWaybills)
                        : _buildWaybillCards(visibleWaybills),
                    if (shouldPaginate) ...[
                      const SizedBox(height: 12),
                      _buildWaybillPaginationControls(
                        totalItems: filteredWaybills.length,
                        visibleCount: visibleWaybills.length,
                        totalPages: totalPages,
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWaybillPaginationControls({
    required int totalItems,
    required int visibleCount,
    required int totalPages,
  }) {
    final start = (_waybillCurrentPage * _waybillItemsPerPage) + 1;
    final end = ((_waybillCurrentPage * _waybillItemsPerPage) + visibleCount)
        .clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start-$end of $totalItems',
              style: const TextStyle(
                color: _onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Previous page',
            onPressed: _waybillCurrentPage == 0
                ? null
                : () => setState(() => _waybillCurrentPage--),
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          Text(
            'Page ${_waybillCurrentPage + 1} of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Next page',
            onPressed: _waybillCurrentPage >= totalPages - 1
                ? null
                : () => setState(() => _waybillCurrentPage++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildWaybillSearchBox() {
    return TextField(
      controller: waybillSearchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search waybill, BAJ number, client, driver or status',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: waybillSearchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  waybillSearchController.clear();
                  setState(() => _waybillCurrentPage = 0);
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _outline.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _outline.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }

  List<WaybillModel> _filteredWaybills() {
    final searchText = waybillSearchController.text.trim().toLowerCase();
    if (searchText.isEmpty) return waybills;

    return waybills.where((waybill) {
      return waybill.waybillNumber.toLowerCase().contains(searchText) ||
          waybill.bajNumber.toLowerCase().contains(searchText) ||
          waybill.shippingVendor.toLowerCase().contains(searchText) ||
          waybill.consigneeReceiver.toLowerCase().contains(searchText) ||
          waybill.driverName.toLowerCase().contains(searchText) ||
          waybill.status.toLowerCase().contains(searchText);
    }).toList();
  }

  Widget _buildWaybillCards(List<WaybillModel> sourceWaybills) {
    return Column(
      children: [
        for (final waybill in sourceWaybills)
          Card(
            color: waybill.isDeleted ? const Color(0xFFFFF3F0) : Colors.white,
            child: ListTile(
              leading: Icon(
                waybill.isDeleted ? Icons.delete_outline : Icons.description,
                color: waybill.isDeleted ? Colors.red : _primary,
              ),
              title: Text(waybill.waybillNumber),
              subtitle: Text(
                'BAJ: ${waybill.bajNumber}\n'
                'Client: ${waybill.shippingVendor}\n'
                'Status: ${waybill.status}',
              ),
              isThreeLine: true,
              onTap: waybill.isDeleted ? null : () => _openWaybill(waybill),
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    onPressed: waybill.isDeleted
                        ? null
                        : () => _editWaybill(waybill),
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: () => _toggleWaybillDeleted(waybill),
                    icon: Icon(
                      waybill.isDeleted ? Icons.restore : Icons.delete_outline,
                    ),
                    tooltip: waybill.isDeleted ? 'Restore' : 'Delete',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaybillTable(List<WaybillModel> sourceWaybills) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1E8F0)),
        ),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1080),
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 18,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 72,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFEAF3FF),
                ),
                columns: const [
                  DataColumn(label: Text('Waybill No.')),
                  DataColumn(label: Text('BAJ No.')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Client/Receiver')),
                  DataColumn(label: Text('Driver')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Center(child: Text('Actions'))),
                ],
                rows: sourceWaybills.map((waybill) {
                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>(
                      (_) => waybill.isDeleted ? const Color(0xFFFFF3F0) : null,
                    ),
                    cells: [
                      DataCell(
                        Text(
                          waybill.waybillNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Text(waybill.bajNumber)),
                      DataCell(Text(waybill.date)),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            waybill.consigneeReceiver.isEmpty
                                ? waybill.shippingVendor
                                : waybill.consigneeReceiver,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            waybill.driverName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        _SuperUserStatusChip(
                          status: waybill.isDeleted
                              ? 'Deleted'
                              : waybill.status,
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: waybill.isDeleted
                                  ? null
                                  : () => _openWaybill(waybill),
                              icon: const Icon(Icons.visibility, size: 16),
                              label: const Text('View'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: waybill.isDeleted
                                  ? null
                                  : () => _editWaybill(waybill),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => _toggleWaybillDeleted(waybill),
                              icon: Icon(
                                waybill.isDeleted
                                    ? Icons.restore
                                    : Icons.delete_outline,
                              ),
                              tooltip: waybill.isDeleted ? 'Restore' : 'Delete',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackupTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryHeader(
          title: 'Backup',
          subtitle: 'Copy a JSON backup of users and waybills',
          icon: Icons.backup,
          action: FilledButton.icon(
            onPressed: _copyBackup,
            icon: const Icon(Icons.copy),
            label: const Text('Copy Backup'),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.email)),
            title: const Text('SMTP Email Settings'),
            subtitle: const Text(
              'Configure the company mail account used to email signed waybills.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showSmtpSettingsDialog,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.analytics_outlined)),
            title: const Text('Rebuild Waybill Stats'),
            subtitle: const Text(
              'Create or refresh appStats/waybillsSummary from existing waybills.',
            ),
            trailing: FilledButton.icon(
              onPressed: isRebuildingStats ? null : _rebuildWaybillStats,
              icon: isRebuildingStats
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(isRebuildingStats ? 'Rebuilding...' : 'Rebuild'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Waybills: ${waybills.length}'),
                const SizedBox(height: 8),
                Text('Users: ${users.length}'),
                const SizedBox(height: 8),
                Text(_backupSourceText()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _backupSourceText() {
    if (isLoading) return 'Source: Loading latest data...';
    if (shouldUseFirestoreData) {
      return 'Source: Firestore with local cache refresh';
    }
    return 'Source: Local cache on this device';
  }

  Widget _loadingDataCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _summaryHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? action,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 24, child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'officer':
      case 'officer in charge':
        return 'Officer';
      case 'driver':
        return 'Driver';
      case 'accounts':
        return 'Accounts';
      case 'management':
        return 'Management';
      case 'manager':
        return 'Manager';
      case 'super_user':
      case 'super user':
      case 'admin':
        return 'Super User';
      default:
        return role;
    }
  }
}

class _SuperUserStatusChip extends StatelessWidget {
  final String status;

  const _SuperUserStatusChip({required this.status});

  Color get _color {
    switch (status) {
      case 'Pending Delivery':
        return Colors.orange;
      case 'Pending Sync':
        return Colors.deepOrange;
      case 'Delivered':
        return Colors.blue;
      case 'Invoiced':
        return Colors.green;
      case 'Deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.32)),
      ),
      child: Text(
        status,
        style: TextStyle(color: _color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
