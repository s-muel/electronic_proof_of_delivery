import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user_model.dart';
import '../models/user_stats_model.dart';
import '../models/waybill_stats_model.dart';
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
  static const int _userItemsPerPage = 25;

  final userSearchController = TextEditingController();
  final waybillSearchController = TextEditingController();
  List<AppUserModel> users = [];
  List<WaybillModel> waybills = [];
  UserStatsModel? userStats;
  WaybillStatsModel? waybillStats;
  String? selectedPage;
  String? openingPage;
  String? selectedUserRoleFilter;
  String? selectedWaybillFilter;
  int _waybillCurrentPage = 0;
  int _userCurrentPage = 0;
  final List<DocumentSnapshot<Map<String, dynamic>>?> _userPageCursors = [null];
  final Map<int, List<AppUserModel>> _userPageCache = {};
  final Map<int, bool> _userPageHasMoreCache = {};
  bool _userHasNextPage = false;
  bool _usingServerUserPagination = false;
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
    UserStatsModel? loadedUserStats;
    WaybillStatsModel? loadedWaybillStats;
    Object? loadWarning;

    final needsUserList = selectedPage == 'users';
    final needsWaybillList =
        selectedPage == 'waybills' || selectedPage == 'backup';

    if (shouldUseFirestoreData) {
      try {
        loadedUserStats = await AppUserService.getUserStats();
        loadedUserStats ??= await AppUserService.rebuildUserStats();
      } catch (error) {
        debugPrint('SUPER USER STATS LOAD ERROR: $error');
        loadWarning = error;
      }

      try {
        loadedWaybillStats = await FirestoreWaybillService.getWaybillStats();
        if (needsUserList) {
          final page = await AppUserService.getUsersPage(
            limit: _userItemsPerPage,
            roleFilter: selectedUserRoleFilter,
          );
          loadedUsers = page.users;
          _userPageCursors
            ..clear()
            ..add(null);
          if (page.hasMore) {
            _userPageCursors.add(page.lastDocument);
          }
          _userPageCache
            ..clear()
            ..[0] = page.users;
          _userPageHasMoreCache
            ..clear()
            ..[0] = page.hasMore;
          _userHasNextPage = page.hasMore;
          _usingServerUserPagination = true;
        }
        if (needsWaybillList) {
          loadedWaybills = await FirestoreWaybillService.getAllWaybills(
            includeDeleted: true,
          );
          await WaybillService.replaceCachedWaybills(loadedWaybills);
          loadedWaybillStats ??= WaybillStatsModel.fromWaybills(loadedWaybills);
        }
      } catch (error) {
        debugPrint('SUPER USER DATA LOAD ERROR: $error');
        loadWarning = error;
        if (needsWaybillList) {
          loadedWaybills = WaybillService.getAllWaybills(includeDeleted: true);
        }
        loadedUserStats ??= UserStatsModel.fromUsers(loadedUsers);
        loadedWaybillStats ??= WaybillStatsModel.fromWaybills(loadedWaybills);
      }
    } else {
      loadedUserStats = UserStatsModel.fromUsers(loadedUsers);
      if (needsWaybillList) {
        loadedWaybills = WaybillService.getAllWaybills(includeDeleted: true);
      }
      loadedWaybillStats = WaybillStatsModel.fromWaybills(loadedWaybills);
    }

    if (!mounted) return;

    setState(() {
      users = loadedUsers;
      if (!needsUserList) {
        _usingServerUserPagination = false;
        _userHasNextPage = false;
        _userPageCache.clear();
        _userPageHasMoreCache.clear();
        _userPageCursors
          ..clear()
          ..add(null);
      }
      waybills = loadedWaybills;
      userStats = loadedUserStats;
      waybillStats = loadedWaybillStats;
      _waybillCurrentPage = 0;
      _userCurrentPage = 0;
      isLoading = false;
    });

    if (loadWarning != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some admin data used cached values. Check debug console.',
          ),
        ),
      );
    }
  }

  Future<void> _loadUsersPage(int pageIndex) async {
    if (!shouldUseFirestoreData) return;

    final cachedPage = _userPageCache[pageIndex];
    if (cachedPage != null) {
      setState(() {
        users = cachedPage;
        _userCurrentPage = pageIndex;
        _userHasNextPage = _userPageHasMoreCache[pageIndex] ?? false;
        _usingServerUserPagination = true;
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      final page = await AppUserService.getUsersPage(
        limit: _userItemsPerPage,
        startAfterDocument: _userPageCursors[pageIndex],
        roleFilter: selectedUserRoleFilter,
      );

      if (_userPageCursors.length <= pageIndex + 1) {
        _userPageCursors.add(page.hasMore ? page.lastDocument : null);
      } else if (page.hasMore) {
        _userPageCursors[pageIndex + 1] = page.lastDocument;
      }

      if (!mounted) return;

      setState(() {
        users = page.users;
        _userCurrentPage = pageIndex;
        _userHasNextPage = page.hasMore;
        _usingServerUserPagination = true;
        _userPageCache[pageIndex] = page.users;
        _userPageHasMoreCache[pageIndex] = page.hasMore;
        isLoading = false;
      });
    } catch (error) {
      debugPrint('SUPER USER PAGE USERS ERROR: $error');
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load users page. Check debug console.'),
        ),
      );
    }
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
    final index = await WaybillService.ensureCachedIndex(waybill);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaybillDetailsScreen(waybill: waybill, index: index),
      ),
    );

    await loadAdminData();
  }

  Future<void> _editWaybill(WaybillModel waybill) async {
    final index = await WaybillService.ensureCachedIndex(waybill);

    if (!mounted) return;

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
    setState(() => isLoading = true);

    try {
      final backupUsers = shouldUseFirestoreData
          ? await AppUserService.getAllUsers()
          : users;
      final backupWaybills = shouldUseFirestoreData
          ? await FirestoreWaybillService.getAllWaybills(includeDeleted: true)
          : waybills;
      final backup = {
        'generatedAt': DateTime.now().toIso8601String(),
        'waybills': backupWaybills
            .map((waybill) => waybill.toFirestoreMap())
            .toList(),
        'users': backupUsers.map((user) => user.toMap()).toList(),
      };

      const encoder = JsonEncoder.withIndent('  ');
      await Clipboard.setData(ClipboardData(text: encoder.convert(backup)));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup copied: ${backupWaybills.length} waybills, ${backupUsers.length} users',
          ),
        ),
      );
    } catch (error) {
      debugPrint('SUPER USER BACKUP ERROR: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not copy backup: $error')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _rebuildWaybillStats() async {
    if (isRebuildingStats) return;

    setState(() => isRebuildingStats = true);

    try {
      final stats = await FirestoreWaybillService.rebuildWaybillStats();
      final rebuiltUserStats = await AppUserService.rebuildUserStats();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stats rebuilt: ${stats.total} waybills, ${rebuiltUserStats.total} users',
          ),
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

  Future<void> _openFilteredUsers(String? roleLabel) async {
    setState(() {
      selectedPage = 'users';
      selectedUserRoleFilter = roleLabel;
      selectedWaybillFilter = null;
      _userCurrentPage = 0;
    });
    await loadAdminData();
  }

  Future<void> _openFilteredWaybills(String? filter) async {
    setState(() {
      selectedPage = 'waybills';
      selectedWaybillFilter = filter;
      selectedUserRoleFilter = null;
      _waybillCurrentPage = 0;
    });
    await loadAdminData();
  }

  Future<void> _openSuperUserPage(String page) async {
    if (openingPage != null) return;

    setState(() => openingPage = page);
    await Future<void>.delayed(const Duration(milliseconds: 160));

    if (!mounted) return;

    setState(() {
      selectedPage = page;
      openingPage = null;
      selectedUserRoleFilter = null;
      selectedWaybillFilter = null;
      _userCurrentPage = 0;
      _waybillCurrentPage = 0;
    });

    await loadAdminData();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUserStats = userStats ?? UserStatsModel.fromUsers(users);
    final effectiveWaybillStats =
        waybillStats ?? WaybillStatsModel.fromWaybills(waybills);
    final activeUsers = effectiveUserStats.active;
    final deletedWaybills = waybills
        .where((waybill) => waybill.isDeleted)
        .length;
    final activeWaybills = effectiveWaybillStats.total;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        final sidebar = _superUserSidebar(isWide: isWide);

        return Scaffold(
          backgroundColor: _background,
          appBar: isWide
              ? null
              : AppBar(
                  backgroundColor: _background.withValues(alpha: 0.96),
                  foregroundColor: _onSurface,
                  elevation: 0,
                  surfaceTintColor: _background,
                  title: Text(
                    _superUserPageTitle(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
          drawer: isWide ? null : Drawer(child: sidebar),
          body: isWide
              ? Row(
                  children: [
                    SizedBox(width: 250, child: sidebar),
                    Expanded(child: body),
                  ],
                )
              : body,
        );
      },
    );
  }

  Widget _superUserSidebar({required bool isWide}) {
    return SafeArea(
      child: Container(
        color: _surface,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BAJ E-POD',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Super User',
                        style: TextStyle(color: _onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sidebarItem(
              label: 'Dashboard',
              icon: Icons.dashboard_rounded,
              selected: selectedPage == null,
              onTap: () => _selectSidebarPage(null),
            ),
            _sidebarItem(
              label: 'User Management',
              icon: Icons.people_alt_rounded,
              selected: selectedPage == 'users',
              onTap: () => _selectSidebarPage('users'),
            ),
            _sidebarItem(
              label: 'Waybill Management',
              icon: Icons.receipt_long_rounded,
              selected: selectedPage == 'waybills',
              onTap: () => _selectSidebarPage('waybills'),
            ),
            _sidebarItem(
              label: 'Backup',
              icon: Icons.backup_rounded,
              selected: selectedPage == 'backup',
              onTap: () => _selectSidebarPage('backup'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: loadAdminData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSidebarPage(String? page) async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    setState(() {
      selectedPage = page;
      selectedUserRoleFilter = null;
      selectedWaybillFilter = null;
      _userCurrentPage = 0;
      _waybillCurrentPage = 0;
    });

    await loadAdminData();
  }

  Widget _sidebarItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? _primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? _primary : _onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? _primary : _onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          const SizedBox(height: 18),
          _superUserSummaryStrip(),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final actionCards = [
                _adminPageCard(
                  title: 'Add User',
                  subtitle: isLoading
                      ? 'Loading users...'
                      : '$activeUsers active users',
                  badge: isLoading
                      ? 'Please wait'
                      : '${userStats?.total ?? users.length} total',
                  icon: Icons.person_add_alt_1,
                  color: _primary,
                  isOpening: false,
                  onTap: _showAddUserDialog,
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

  Widget _superUserSummaryStrip() {
    final users = userStats ?? UserStatsModel.fromUsers(this.users);
    final bills = waybillStats ?? WaybillStatsModel.fromWaybills(waybills);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summarySectionTitle('Waybills'),
        _summaryCardWrap([
          _superSummaryCard(
            title: 'Total Waybills',
            value: bills.total.toString(),
            icon: Icons.receipt_long,
            color: Colors.indigo,
            onTap: () => _openFilteredWaybills(null),
          ),
          _superSummaryCard(
            title: 'Pending',
            value: bills.pendingDelivery.toString(),
            icon: Icons.schedule,
            color: Colors.orange,
            onTap: () => _openFilteredWaybills('pending'),
          ),
          _superSummaryCard(
            title: 'Delivered',
            value: bills.delivered.toString(),
            icon: Icons.local_shipping,
            color: Colors.blue,
            onTap: () => _openFilteredWaybills('delivered'),
          ),
          _superSummaryCard(
            title: 'Sent for Invoicing',
            value: bills.sentForInvoicing.toString(),
            icon: Icons.outbox,
            color: Colors.deepPurple,
            onTap: () => _openFilteredWaybills('sentForInvoicing'),
          ),
          _superSummaryCard(
            title: 'Invoiced',
            value: bills.invoiced.toString(),
            icon: Icons.done_all,
            color: Colors.green,
            onTap: () => _openFilteredWaybills('invoiced'),
          ),
          _superSummaryCard(
            title: 'Rejected',
            value: bills.rejected.toString(),
            icon: Icons.report_problem,
            color: Colors.red,
            onTap: () => _openFilteredWaybills('rejected'),
          ),
        ]),
        const SizedBox(height: 20),
        _summarySectionTitle('Users'),
        _summaryCardWrap([
          _superSummaryCard(
            title: 'Super User',
            value: users.superUsers.toString(),
            icon: Icons.admin_panel_settings,
            color: _primary,
            onTap: () => _openFilteredUsers('Super User'),
          ),
          _superSummaryCard(
            title: 'Officer',
            value: users.officers.toString(),
            icon: Icons.assignment_ind,
            color: Colors.indigo,
            onTap: () => _openFilteredUsers('Officer'),
          ),
          _superSummaryCard(
            title: 'Driver',
            value: users.drivers.toString(),
            icon: Icons.local_shipping,
            color: Colors.blue,
            onTap: () => _openFilteredUsers('Driver'),
          ),
          _superSummaryCard(
            title: 'Account',
            value: users.accounts.toString(),
            icon: Icons.receipt_long,
            color: Colors.green,
            onTap: () => _openFilteredUsers('Accounts'),
          ),
          _superSummaryCard(
            title: 'Management',
            value: users.management.toString(),
            icon: Icons.insights,
            color: Colors.orange,
            onTap: () => _openFilteredUsers('Management'),
          ),
          _superSummaryCard(
            title: 'Manager',
            value: users.managers.toString(),
            icon: Icons.manage_accounts,
            color: Colors.red,
            onTap: () => _openFilteredUsers('Manager'),
          ),
        ]),
      ],
    );
  }

  Widget _summarySectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: _onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _summaryCardWrap(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 6
            : (constraints.maxWidth >= 640 ? 3 : 1);
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: itemWidth, child: card),
          ],
        );
      },
    );
  }

  Widget _superSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color, size: 20),
            ],
          ),
        ),
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
                    const SizedBox(height: 5),
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
    final totalFilteredUsers = _totalUsersForRole(selectedUserRoleFilter);
    final shouldPaginate = _usingServerUserPagination
        ? (_userCurrentPage > 0 || _userHasNextPage)
        : filteredUsers.length > _userItemsPerPage;
    final visibleCount = filteredUsers.length;
    final roleFilter = selectedUserRoleFilter;

    return RefreshIndicator(
      onRefresh: loadAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryHeader(
            title: roleFilter == null ? 'User Management' : '$roleFilter Users',
            subtitle: isLoading
                ? 'Loading users...'
                : '$activeUsers active of ${userStats?.total ?? users.length} total users',
            icon: Icons.admin_panel_settings,
            action: FilledButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
            ),
          ),
          if (roleFilter != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text('Filter: $roleFilter'),
                avatar: const Icon(Icons.filter_alt, size: 18),
                onDeleted: () => _openFilteredUsers(null),
              ),
            ),
          ],
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
                child: Text('No users match this filter.'),
              ),
            )
          else ...[
            for (final entry in usersByRole.entries)
              _buildRoleUserSection(
                roleLabel: entry.key,
                roleUsers: entry.value,
                totalRoleUsers: roleFilter == null ? null : totalFilteredUsers,
              ),
            if (shouldPaginate) ...[
              const SizedBox(height: 12),
              _buildUserPaginationControls(
                totalItems: totalFilteredUsers,
                visibleCount: visibleCount,
                totalPages: 0,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildUserPaginationControls({
    required int totalItems,
    required int visibleCount,
    required int totalPages,
  }) {
    final start = (_userCurrentPage * _userItemsPerPage) + 1;
    final end = ((_userCurrentPage * _userItemsPerPage) + visibleCount).clamp(
      0,
      totalItems,
    );

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
              _usingServerUserPagination
                  ? 'Showing $start-$end of $totalItems users'
                  : 'Showing $start-$end of $totalItems users',
              style: const TextStyle(
                color: _onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Previous page',
            onPressed: _userCurrentPage == 0
                ? null
                : () => _usingServerUserPagination
                      ? _loadUsersPage(_userCurrentPage - 1)
                      : setState(() => _userCurrentPage--),
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          Text(
            _usingServerUserPagination
                ? 'Page ${_userCurrentPage + 1}'
                : 'Page ${_userCurrentPage + 1} of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Next page',
            onPressed: _usingServerUserPagination
                ? (_userHasNextPage
                      ? () => _loadUsersPage(_userCurrentPage + 1)
                      : null)
                : (_userCurrentPage >= totalPages - 1
                      ? null
                      : () => setState(() => _userCurrentPage++)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSearchBox() {
    return TextField(
      controller: userSearchController,
      onChanged: (_) => setState(() => _userCurrentPage = 0),
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
    final roleFilter = selectedUserRoleFilter;
    final sourceUsers = roleFilter == null
        ? users
        : users.where((user) => _roleLabel(user.role) == roleFilter).toList();
    if (searchText.isEmpty) return sourceUsers;

    return sourceUsers.where((user) {
      final displayName = user.fullName.isEmpty ? user.email : user.fullName;
      final roleLabel = _roleLabel(user.role);

      return displayName.toLowerCase().contains(searchText) ||
          user.email.toLowerCase().contains(searchText) ||
          roleLabel.toLowerCase().contains(searchText) ||
          user.role.toLowerCase().contains(searchText) ||
          user.department.toLowerCase().contains(searchText);
    }).toList();
  }

  int _totalUsersForRole(String? roleFilter) {
    final stats = userStats;
    if (stats == null || roleFilter == null) {
      return stats?.total ?? users.length;
    }

    switch (roleFilter) {
      case 'Super User':
        return stats.superUsers;
      case 'Officer':
        return stats.officers;
      case 'Driver':
        return stats.drivers;
      case 'Accounts':
        return stats.accounts;
      case 'Management':
        return stats.management;
      case 'Manager':
        return stats.managers;
      default:
        return users.length;
    }
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
    int? totalRoleUsers,
  }) {
    final activeCount = roleUsers.where((user) => user.isActive).length;
    final subtitle = totalRoleUsers == null
        ? '$activeCount active of ${roleUsers.length} users'
        : 'Showing ${roleUsers.length} of $totalRoleUsers users';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _outline.withValues(alpha: 0.45)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          collapsedBackgroundColor: const Color(0xFFF7FAFD),
          iconColor: Colors.blue,
          collapsedIconColor: Colors.blue,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_roleIcon(roleLabel), color: Colors.blue, size: 18),
          ),
          title: Text(
            roleLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
          ),
          children: [
            for (var index = 0; index < roleUsers.length; index++)
              _buildUserRow(
                roleUsers[index],
                showDivider: index < roleUsers.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow(AppUserModel user, {required bool showDivider}) {
    final displayName = user.fullName.trim().isEmpty
        ? user.email.trim()
        : user.fullName.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: showDivider
            ? Border(bottom: BorderSide(color: _outline.withValues(alpha: 0.3)))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _userInitialAvatar(user),
                    const SizedBox(width: 12),
                    Expanded(child: _userIdentity(displayName, user.email)),
                    _userActions(user),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 22,
                  runSpacing: 10,
                  children: [
                    _userMetaBlock(
                      label: 'Status',
                      value: user.isActive ? 'Active' : 'Inactive',
                      valueColor: user.isActive
                          ? const Color(0xFF008A4C)
                          : const Color(0xFFB42318),
                    ),
                    _userMetaBlock(
                      label: 'Department',
                      value: user.department.trim().isEmpty
                          ? '-'
                          : user.department.trim(),
                    ),
                    _userMetaBlock(
                      label: 'Temp Pass',
                      value: user.tempPass.trim().isEmpty
                          ? '-'
                          : user.tempPass.trim(),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              _userInitialAvatar(user),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: _userIdentity(displayName, user.email)),
              Expanded(
                flex: 2,
                child: _userMetaBlock(
                  label: 'Status',
                  value: user.isActive ? 'Active' : 'Inactive',
                  valueColor: user.isActive
                      ? const Color(0xFF008A4C)
                      : const Color(0xFFB42318),
                ),
              ),
              Expanded(
                flex: 2,
                child: _userMetaBlock(
                  label: 'Department',
                  value: user.department.trim().isEmpty
                      ? '-'
                      : user.department.trim(),
                ),
              ),
              Expanded(
                flex: 2,
                child: _userMetaBlock(
                  label: 'Temp Pass',
                  value: user.tempPass.trim().isEmpty
                      ? '-'
                      : user.tempPass.trim(),
                ),
              ),
              _userActions(user),
            ],
          );
        },
      ),
    );
  }

  Widget _userInitialAvatar(AppUserModel user) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: _avatarColor(user),
      child: Text(
        _userInitials(user),
        style: const TextStyle(
          color: Color(0xFF4F46E5),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _userIdentity(String displayName, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          email,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _userMetaBlock({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8A94B8),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? _onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _userActions(AppUserModel user) {
    return Wrap(
      spacing: 8,
      children: [
        IconButton(
          onPressed: () => _sendPasswordReset(user),
          icon: const Icon(Icons.lock_reset),
          color: const Color(0xFF8FA0BC),
          tooltip: 'Send Password Reset',
        ),
        IconButton(
          onPressed: () => _toggleUserActive(user),
          icon: Icon(user.isActive ? Icons.block : Icons.check_circle),
          color: const Color(0xFF8FA0BC),
          tooltip: user.isActive ? 'Deactivate' : 'Reactivate',
        ),
      ],
    );
  }

  String _userInitials(AppUserModel user) {
    final source = user.fullName.trim().isEmpty
        ? user.email.trim()
        : user.fullName.trim();
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Color _avatarColor(AppUserModel user) {
    final colors = [
      const Color(0xFFE2E7FF),
      const Color(0xFFE8F3FF),
      const Color(0xFFFFF1BF),
      const Color(0xFFF1F5F9),
    ];
    final source = user.email.isEmpty ? user.fullName : user.email;
    final index = source.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return colors[index % colors.length];
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
    final waybillFilterLabel = _waybillFilterLabel(selectedWaybillFilter);

    return RefreshIndicator(
      onRefresh: loadAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryHeader(
            title: waybillFilterLabel == null
                ? 'Waybill Management'
                : '$waybillFilterLabel Waybills',
            subtitle: isLoading
                ? 'Loading waybills...'
                : '${waybills.length - deletedWaybills} active, $deletedWaybills deleted',
            icon: Icons.receipt_long,
          ),
          if (waybillFilterLabel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text('Filter: $waybillFilterLabel'),
                avatar: const Icon(Icons.filter_alt, size: 18),
                onDeleted: () => setState(() {
                  selectedWaybillFilter = null;
                  _waybillCurrentPage = 0;
                }),
              ),
            ),
          ],
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
    final categoryFiltered = waybills.where((waybill) {
      switch (selectedWaybillFilter) {
        case 'pending':
          return waybill.status == WaybillService.pendingDeliveryStatus &&
              waybill.invoiceStatus != WaybillService.invoiceRejectedStatus;
        case 'delivered':
          return waybill.status == WaybillService.deliveredStatus &&
              waybill.invoiceStatus != WaybillService.invoiceRejectedStatus;
        case 'sentForInvoicing':
          return waybill.invoiceStatus == WaybillService.invoiceSentStatus;
        case 'invoiced':
          return waybill.status == WaybillService.invoicedStatus &&
              waybill.invoiceStatus != WaybillService.invoiceRejectedStatus;
        case 'rejected':
          return waybill.invoiceStatus == WaybillService.invoiceRejectedStatus;
        default:
          return true;
      }
    }).toList();

    if (searchText.isEmpty) return categoryFiltered;

    return categoryFiltered.where((waybill) {
      return waybill.waybillNumber.toLowerCase().contains(searchText) ||
          waybill.bajNumber.toLowerCase().contains(searchText) ||
          waybill.shippingVendor.toLowerCase().contains(searchText) ||
          waybill.consigneeReceiver.toLowerCase().contains(searchText) ||
          waybill.driverName.toLowerCase().contains(searchText) ||
          waybill.invoiceStatus.toLowerCase().contains(searchText) ||
          waybill.status.toLowerCase().contains(searchText);
    }).toList();
  }

  String? _waybillFilterLabel(String? filter) {
    switch (filter) {
      case 'pending':
        return 'Pending';
      case 'delivered':
        return 'Delivered';
      case 'sentForInvoicing':
        return 'Sent for Invoicing';
      case 'invoiced':
        return 'Invoiced';
      case 'rejected':
        return 'Rejected';
      default:
        return null;
    }
  }

  String _displayWaybillStatus(WaybillModel waybill) {
    if (waybill.isDeleted) return 'Deleted';
    if (waybill.invoiceStatus != WaybillService.invoiceNotSentStatus) {
      return waybill.invoiceStatus == WaybillService.invoiceAcceptedStatus
          ? WaybillService.invoicedStatus
          : waybill.invoiceStatus;
    }
    return waybill.status;
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
                'Status: ${_displayWaybillStatus(waybill)}',
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
                          status: _displayWaybillStatus(waybill),
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
                Text('Users: ${userStats?.total ?? users.length}'),
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
      case 'Sent for Invoicing':
        return Colors.indigo;
      case 'Invoiced':
        return Colors.green;
      case 'Rejected':
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
