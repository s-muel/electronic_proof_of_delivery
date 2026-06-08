import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user_model.dart';
import '../models/waybill_model.dart';
import '../services/app_user_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_waybill_service.dart';
import '../services/waybill_service.dart';
import '../utils/platform_flags.dart';
import 'login_screen.dart';
import 'waybill_details_screen.dart';

class SuperUserDashboard extends StatefulWidget {
  const SuperUserDashboard({super.key});

  @override
  State<SuperUserDashboard> createState() => _SuperUserDashboardState();
}

class _SuperUserDashboardState extends State<SuperUserDashboard> {
  List<AppUserModel> users = [];
  List<WaybillModel> waybills = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAdminData();
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
        currentUser?.email ?? FirebaseAuthService.currentFirebaseUser?.email ?? '';

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
    var selectedRole = 'officer';
    var isSaving = false;

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
                            if (email.isEmpty) return 'Email is required';
                            if (!email.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Temporary Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Use at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
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
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
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
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext, true);
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('Could not add user: $error')),
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

    if (userCreated == true) {
      await loadAdminData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User added successfully')),
      );
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

  @override
  Widget build(BuildContext context) {
    final activeUsers = users.where((user) => user.isActive).length;
    final deletedWaybills = waybills.where((waybill) => waybill.isDeleted).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Super User Dashboard'),
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
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Waybills'),
              Tab(icon: Icon(Icons.backup), text: 'Backup'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildUsersTab(activeUsers),
                  _buildWaybillsTab(deletedWaybills),
                  _buildBackupTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildUsersTab(int activeUsers) {
    return RefreshIndicator(
      onRefresh: loadAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryHeader(
            title: 'User Management',
            subtitle: '$activeUsers active of ${users.length} total users',
            icon: Icons.admin_panel_settings,
            action: FilledButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
            ),
          ),
          const SizedBox(height: 12),
          for (final user in users)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(user.isActive ? Icons.person : Icons.person_off),
                ),
                title: Text(user.fullName.isEmpty ? user.email : user.fullName),
                subtitle: Text('${user.email}\nRole: ${_roleLabel(user.role)}'),
                isThreeLine: true,
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
                      icon: Icon(
                        user.isActive ? Icons.block : Icons.check_circle,
                      ),
                      tooltip: user.isActive ? 'Deactivate' : 'Reactivate',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaybillsTab(int deletedWaybills) {
    return RefreshIndicator(
      onRefresh: loadAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryHeader(
            title: 'Waybill Management',
            subtitle:
                '${waybills.length - deletedWaybills} active, $deletedWaybills deleted',
            icon: Icons.receipt_long,
          ),
          const SizedBox(height: 12),
          for (final waybill in waybills)
            Card(
              color: waybill.isDeleted ? const Color(0xFFFFF3F0) : Colors.white,
              child: ListTile(
                leading: Icon(
                  waybill.isDeleted ? Icons.delete_outline : Icons.description,
                  color: waybill.isDeleted ? Colors.red : Colors.blue,
                ),
                title: Text(waybill.waybillNumber),
                subtitle: Text(
                  'BAJ: ${waybill.bajNumber}\nClient: ${waybill.shippingVendor}\nStatus: ${waybill.status}',
                ),
                isThreeLine: true,
                onTap: waybill.isDeleted ? null : () => _openWaybill(waybill),
                trailing: IconButton(
                  onPressed: () => _toggleWaybillDeleted(waybill),
                  icon: Icon(
                    waybill.isDeleted ? Icons.restore : Icons.delete_outline,
                  ),
                  tooltip: waybill.isDeleted ? 'Restore' : 'Delete',
                ),
              ),
            ),
        ],
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Waybills: ${waybills.length}'),
                const SizedBox(height: 8),
                Text('Users: ${users.length}'),
                const SizedBox(height: 8),
                Text(
                  shouldUseFirestoreData
                      ? 'Source: Firestore with local cache refresh'
                      : 'Source: Local cache on this device',
                ),
              ],
            ),
          ),
        ),
      ],
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
            if (action != null) action,
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
      case 'manager':
        return 'Management';
      case 'super_user':
      case 'super user':
      case 'admin':
        return 'Super User';
      default:
        return role;
    }
  }
}
