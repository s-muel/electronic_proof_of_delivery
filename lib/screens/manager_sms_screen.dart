import 'dart:math';

import 'package:flutter/material.dart';

import '../models/app_user_model.dart';
import '../services/app_user_service.dart';
import '../services/driver_sms_service.dart';

class ManagerSmsScreen extends StatefulWidget {
  const ManagerSmsScreen({
    super.key,
    this.previewDrivers,
    this.embedded = false,
  });

  final bool embedded;

  // Supplied only by the isolated UI preview/test harness.
  final List<AppUserModel>? previewDrivers;

  @override
  State<ManagerSmsScreen> createState() => _ManagerSmsScreenState();
}

class _ManagerSmsScreenState extends State<ManagerSmsScreen> {
  static const _blue = Color(0xFF15549D);
  static const _ink = Color(0xFF192E48);
  static const _muted = Color(0xFF506680);
  static const _line = Color(0xFFD4DFEB);
  static const _surface = Color(0xFFF5F8FB);
  static const _sectionLabel = TextStyle(
    color: _ink,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: .7,
  );

  final _search = TextEditingController();
  final _historySearch = TextEditingController();
  DateTime? _historyMonth;
  bool _findOffice = false;
  List<AppUserModel> _officeStaff = [];
  bool _loadingOffice = false;
  bool _officeLoaded = false;
  String? _officeError;
  final _message = TextEditingController();
  String _greeting = '';

  String get _instructions {
    final text = _message.text;
    return (_greeting.isNotEmpty && text.startsWith(_greeting)
            ? text.substring(_greeting.length)
            : text)
        .trim();
  }

  void _updateGreeting() {
    final next = switch (_recipients.length) {
      0 => '',
      1 => 'Hello ${_recipients.values.single.fullName.trim()},\n\n',
      _ => 'Hello Team,\n\n',
    };
    if (next == _greeting) return;
    final text = _message.text;
    final body = _greeting.isNotEmpty && text.startsWith(_greeting)
        ? text.substring(_greeting.length)
        : text;
    _greeting = next;
    final draft = next + body;
    _message.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  final _recipientScroll = ScrollController();
  final _recipients = <String, AppUserModel>{};
  final _phones = <String, String>{};
  final _retry = <String, Map<String, String>>{};
  List<AppUserModel> _drivers = [];
  List<Map<String, dynamic>> _history = [];
  String? _cursor, _driverError, _historyError;
  String _result = '';
  bool _loadingDrivers = true, _loadingHistory = true;
  bool _sending = false;
  bool _selectingAll = false;
  int _tab = 0;

  bool get _unconfirmed => _retry.isNotEmpty;

  bool get _preview => widget.previewDrivers != null;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _loadHistory();
  }

  @override
  void dispose() {
    _search.dispose();
    _historySearch.dispose();
    _message.dispose();
    _recipientScroll.dispose();
    super.dispose();
  }

  String _error(Object error) => error is StateError
      ? error.message
      : 'Could not reach the service. Try again when connected.';

  Future<void> _loadOfficeStaff() async {
    if (_loadingOffice || _preview) return;
    setState(() {
      _loadingOffice = true;
      _officeError = null;
    });
    try {
      final data = await DriverSmsService.request(officeDirectory: true);
      if (!mounted) return;
      setState(() {
        _officeStaff = (data['members'] as List)
            .map((item) => AppUserModel.fromMap(item as Map<String, dynamic>))
            .toList();
        _officeLoaded = true;
        if (_sending || _unconfirmed) return;
        final current = {for (final staff in _officeStaff) staff.userId: staff};
        for (final id in _recipients.keys.toList()) {
          if (_recipients[id]!.role == 'driver') continue;
          final staff = current[id];
          if (staff == null) {
            _recipients.remove(id);
            _phones.remove(id);
          } else {
            if (staff.phoneNumber != _recipients[id]!.phoneNumber) {
              _phones[id] = staff.phoneNumber;
            }
            _recipients[id] = staff;
          }
        }
        _updateGreeting();
      });
    } catch (error) {
      if (mounted) setState(() => _officeError = _error(error));
    } finally {
      if (mounted) setState(() => _loadingOffice = false);
    }
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _loadingDrivers = true;
      _driverError = null;
    });
    try {
      final drivers =
          widget.previewDrivers ??
          await AppUserService.getActiveDrivers().timeout(
            const Duration(seconds: 15),
          );
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        if (_sending || _unconfirmed) return;
        final current = {for (final driver in drivers) driver.userId: driver};
        for (final id in _recipients.keys.toList()) {
          if (_recipients[id]!.role != 'driver') continue;
          final refreshed = current[id];
          if (refreshed == null) {
            _recipients.remove(id);
            _phones.remove(id);
          } else {
            if (refreshed.phoneNumber != _recipients[id]!.phoneNumber) {
              _phones[id] = refreshed.phoneNumber;
            }
            _recipients[id] = refreshed;
          }
        }
        _updateGreeting();
      });
    } catch (error) {
      if (mounted) setState(() => _driverError = _error(error));
    } finally {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  Future<void> _loadHistory({bool more = false}) async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      if (_preview) return;
      final page = await DriverSmsService.request(
        cursor: more ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        final records = (page['records'] as List).cast<Map<String, dynamic>>();
        if (_sending) return;
        _history = more ? [..._history, ...records] : records;
        _cursor = page['cursor'] as String?;
      });
    } catch (error) {
      if (mounted) setState(() => _historyError = _error(error));
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _selectDriver(AppUserModel driver) {
    setState(() {
      _recipients[driver.userId] = driver;
      _phones[driver.userId] = driver.phoneNumber;
      _updateGreeting();
      _search.clear();
      _result = '';
    });
  }

  Future<void> _selectAllDrivers() async {
    if (_selectingAll) return;
    setState(() => _selectingAll = true);
    try {
      // Paint the indicator before building the expanded recipient list.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      setState(() {
        for (final driver in _drivers) {
          _recipients.putIfAbsent(driver.userId, () => driver);
          _phones.putIfAbsent(driver.userId, () => driver.phoneNumber);
        }
        _updateGreeting();
        _search.clear();
        _result = '';
      });
    } finally {
      if (mounted) setState(() => _selectingAll = false);
    }
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    if (_sending ||
        _selectingAll ||
        _instructions.isEmpty ||
        message.length > 480 ||
        _recipients.isEmpty ||
        _recipients.keys.any((id) => _phones[id]!.trim().isEmpty)) {
      return;
    }
    setState(() => _sending = true);
    try {
      if (!_unconfirmed) {
        final rng = Random.secure();
        String newId() => List.generate(
          16,
          (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        final batchId = newId();
        for (final id in _recipients.keys) {
          _retry[id] = {
            'requestId': newId(),
            'batchId': batchId,
            'driverId': id,
            if (_recipients[id]!.role != 'driver') 'recipientType': 'office',
            'phone': _phones[id]!.trim(),
            'message': message,
          };
        }
      }

      if (!_preview) {
        await _queueSms();
        return;
      }

      setState(() {
        _history = [
          for (final entry in _retry.entries)
            {
              ...entry.value,
              'driverName': _recipients[entry.key]!.fullName,
              'senderName': 'Preview manager',
              'status': 'preview',
              'createdAt': DateTime.now().toIso8601String(),
            },
          ..._history,
        ];
        _retry.clear();
        _recipients.clear();
        _phones.clear();
        _message.clear();
        _greeting = '';
        _result = 'Preview saved. No SMS was sent.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _queueSms() async {
    final messenger = ScaffoldMessenger.of(context);
    void showResult(String message) {
      if (!messenger.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    showResult('Sending SMS…');
    final entries = _retry.values.toList(growable: false);
    final first = entries.first;
    try {
      final response = await DriverSmsService.request(
        data: {
          'action': 'queue',
          'batchId': first['batchId'],
          'message': first['message'],
          'recipients': [
            for (final entry in entries)
              {
                'requestId': entry['requestId'],
                'driverId': entry['driverId'],
                'phone': entry['phone'],
                if (entry.containsKey('recipientType'))
                  'recipientType': entry['recipientType'],
              },
          ],
        },
      );
      final records = (response['records'] as List)
          .cast<Map<String, dynamic>>();
      final ids = records.map((row) => row['requestId']).toSet();
      final queued = records
          .where(
            (row) => row['status'] == 'queued' || row['status'] == 'processing',
          )
          .length;
      final previews = records
          .where((row) => row['status'] == 'preview')
          .length;
      final failed = records.where((row) => row['status'] == 'failed').length;
      final submitted =
          queued +
          records
              .where(
                (row) => [
                  'accepted',
                  'delivered',
                ].contains(DriverSmsService.displayStatus(row)),
              )
              .length;
      final feedback = [
        if (submitted > 0)
          submitted == 1 ? 'Message sent.' : '$submitted messages sent.',
        if (previews > 0) 'Preview saved. No SMS was sent.',
        if (failed > 0)
          failed == 1
              ? 'Message could not be sent.'
              : '$failed messages could not be sent.',
        if (submitted + previews + failed < records.length)
          'Check SMS History for unconfirmed messages.',
      ].join('\n');
      if (feedback.isNotEmpty) showResult(feedback);
      if (!mounted) return;
      setState(() {
        _history = [
          ...records,
          ..._history.where((row) => !ids.contains(row['requestId'])),
        ];
        _retry.clear();
        _recipients.clear();
        _phones.clear();
        _message.clear();
        _greeting = '';
        _result = '';
      });
    } on SmsRejected catch (error) {
      showResult(error.message);
      if (!mounted) return;
      setState(() {
        _retry.clear();
        _result = error.message;
      });
    } catch (error) {
      showResult('Send could not be confirmed. Check SMS History.');
      if (!mounted) return;
      setState(() {
        _result = '${_error(error)} Retry the same batch to avoid duplicates.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final directoryLoading = _findOffice ? _loadingOffice : _loadingDrivers;
    final directoryError = _findOffice ? _officeError : _driverError;
    final query = _search.text.trim().toLowerCase();
    final results = query.isEmpty
        ? <AppUserModel>[]
        : (_findOffice ? _officeStaff : _drivers)
              .where(
                (d) =>
                    !_recipients.containsKey(d.userId) &&
                    '${d.fullName} ${d.phoneNumber}'.toLowerCase().contains(
                      query,
                    ),
              )
              .toList();
    final locked = _sending || _unconfirmed || _selectingAll;
    final hasPhone = _recipients.keys.every(
      (id) => _phones[id]!.trim().isNotEmpty,
    );
    final base = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _line),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: _blue,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: _ink,
          onSurfaceVariant: _muted,
        ),
        textTheme: base.textTheme.apply(bodyColor: _ink, displayColor: _ink),
        cardTheme: CardThemeData(
          elevation: 0,
          color: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _line),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          labelStyle: const TextStyle(color: _muted, fontSize: 13),
          helperStyle: const TextStyle(color: _muted, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: _blue, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            textStyle: TextStyle(
              fontFamily: base.textTheme.labelLarge?.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: widget.embedded
              ? null
              : AppBar(title: const Text('SMS · Driver assignments')),
          backgroundColor: Colors.white,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  TabBar(
                    onTap: (index) {
                      setState(() => _tab = index);
                      if (index == 1 && !_loadingHistory && !_sending) {
                        _loadHistory();
                      }
                    },
                    tabs: const [
                      Tab(text: 'Compose'),
                      Tab(text: 'SMS History'),
                    ],
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      sizing: StackFit.expand,
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Text(
                              'Notify drivers',
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'Add one or more drivers, enter the job instructions and send an SMS.',
                            ),
                            if (_preview)
                              const Text(
                                'Preview mode · No real messages are sent',
                              ),
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Find Drivers'),
                                          selected: !_findOffice,
                                          onSelected: locked
                                              ? null
                                              : (_) => _setDirectory(false),
                                        ),
                                        ChoiceChip(
                                          label: const Text(
                                            'Find Office Staff',
                                          ),
                                          selected: _findOffice,
                                          onSelected: locked
                                              ? null
                                              : (_) => _setDirectory(true),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _search,
                                      enabled: !locked,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: _findOffice
                                            ? 'Search your department by name or phone'
                                            : 'Search driver by name or phone',
                                        prefixIcon: const Icon(Icons.search),
                                        suffixIcon: IconButton(
                                          tooltip: _findOffice
                                              ? 'Refresh office staff'
                                              : 'Refresh drivers',
                                          onPressed: locked || directoryLoading
                                              ? null
                                              : (_findOffice
                                                    ? _loadOfficeStaff
                                                    : _loadDrivers),
                                          icon: const Icon(Icons.refresh),
                                        ),
                                      ),
                                    ),
                                    if (directoryLoading || _selectingAll)
                                      LinearProgressIndicator(
                                        semanticsLabel: _selectingAll
                                            ? 'Selecting all drivers'
                                            : (_findOffice
                                                  ? 'Loading office staff'
                                                  : 'Loading drivers'),
                                      ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 8,
                                        children: [
                                          if (!_findOffice)
                                            TextButton.icon(
                                              onPressed:
                                                  locked ||
                                                      _loadingDrivers ||
                                                      _driverError != null ||
                                                      !_drivers.any(
                                                        (driver) => !_recipients
                                                            .containsKey(
                                                              driver.userId,
                                                            ),
                                                      )
                                                  ? null
                                                  : _selectAllDrivers,
                                              icon: const Icon(
                                                Icons.groups_outlined,
                                              ),
                                              label: const Text(
                                                'Select all drivers',
                                              ),
                                            ),
                                          TextButton.icon(
                                            onPressed:
                                                locked || _recipients.isEmpty
                                                ? null
                                                : () => setState(() {
                                                    _recipients.clear();
                                                    _phones.clear();
                                                    _updateGreeting();
                                                    _search.clear();
                                                    _result = '';
                                                  }),
                                            icon: const Icon(Icons.deselect),
                                            label: const Text(
                                              'Unselect all drivers',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (directoryError != null)
                                      Text(directoryError),
                                    if (query.isNotEmpty &&
                                        !directoryLoading &&
                                        directoryError == null &&
                                        results.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          _findOffice
                                              ? 'No matching office staff in your department.'
                                              : 'No matching drivers.',
                                        ),
                                      ),
                                    if (results.length > 6)
                                      const Text(
                                        'Showing the first 6 matches. Refine your search.',
                                      ),
                                    for (final driver in results.take(6))
                                      ListTile(
                                        leading: const Icon(
                                          Icons.person_add_outlined,
                                        ),
                                        title: Text(driver.fullName),
                                        subtitle: Text(
                                          driver.phoneNumber.isEmpty
                                              ? 'No phone number saved'
                                              : driver.phoneNumber,
                                        ),
                                        onTap: locked
                                            ? null
                                            : () => _selectDriver(driver),
                                      ),
                                    if (_recipients.isNotEmpty) ...[
                                      const Divider(),
                                      Text(
                                        'Recipients (${_recipients.length})',
                                        style: _sectionLabel,
                                      ),
                                      _recipientList(locked),
                                    ],
                                    const SizedBox(height: 12),
                                    const Text(
                                      'JOB INSTRUCTIONS & SMS CONTENT',
                                      style: _sectionLabel,
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _message,
                                      enabled: !locked,
                                      maxLength: 480,
                                      minLines: 6,
                                      maxLines: null,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        labelText: 'Job instructions',
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.icon(
                                        onPressed:
                                            _sending ||
                                                _selectingAll ||
                                                _recipients.isEmpty ||
                                                !hasPhone ||
                                                _instructions.isEmpty ||
                                                _message.text.trim().length >
                                                    480
                                            ? null
                                            : _send,
                                        icon: Icon(
                                          _unconfirmed
                                              ? Icons.refresh
                                              : Icons.send_outlined,
                                        ),
                                        label: Text(
                                          _sending
                                              ? 'Queueing…'
                                              : _unconfirmed
                                              ? 'Retry same batch'
                                              : 'Send SMS',
                                        ),
                                      ),
                                    ),
                                    if (_result.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(_result),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              child: _historyFilters(),
                            ),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  20,
                                ),
                                children: [
                                  if (_loadingHistory)
                                    const LinearProgressIndicator(),
                                  if (_historyError != null)
                                    Text(_historyError!),
                                  if (!_loadingHistory &&
                                      _historyError == null &&
                                      _history.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text('No SMS attempts yet.'),
                                    ),
                                  if (_history.isNotEmpty) _historyCards(),
                                  if (_cursor != null)
                                    TextButton(
                                      onPressed: _loadingHistory || _sending
                                          ? null
                                          : () => _loadHistory(more: true),
                                      child: const Text('Load older messages'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _historyStatus(Object? status) => switch (status) {
    'queued' => 'Queued',
    'processing' => 'Sending',
    'accepted' => 'Sent',
    'delivered' => 'Delivered',
    'not_delivered' => 'Not delivered',
    'preview' => 'Preview',
    'failed' => 'Failed',
    'unknown' => 'Unconfirmed',
    _ => 'Pending',
  };

  Widget _historyFilters() {
    final now = DateTime.now();
    final months = <DateTime>{
      for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i),
      ?_historyMonth,
      for (final row in _history)
        if (DateTime.tryParse('${row['createdAt']}')?.toLocal()
            case final DateTime date)
          DateTime(date.year, date.month),
    }.toList()..sort((a, b) => b.compareTo(a));
    final title = Text(
      'SMS History',
      style: Theme.of(context).textTheme.titleLarge,
    );
    Widget search({bool compact = false}) => TextField(
      controller: _historySearch,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: compact ? 'Recipient name' : 'Search recipient name',
        prefixIcon: const Icon(Icons.search, size: 18),
        prefixIconConstraints: compact
            ? const BoxConstraints(minWidth: 32)
            : null,
      ),
    );
    Widget filter({bool compact = false}) => DropdownButtonFormField<DateTime?>(
      initialValue: _historyMonth,
      isExpanded: true,
      borderRadius: BorderRadius.circular(10),
      icon: const Icon(Icons.expand_more, color: _blue, size: 20),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: _ink, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Month',
        filled: true,
        fillColor: _surface,
        prefixIcon: compact
            ? null
            : const Icon(Icons.calendar_month_outlined, color: _blue, size: 17),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All months')),
        for (final month in months)
          DropdownMenuItem(
            value: month,
            child: Text(
              MaterialLocalizations.of(context).formatMonthYear(month),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (month) => setState(() => _historyMonth = month),
    );
    Widget refresh({bool compact = false}) => IconButton(
      tooltip: 'Refresh history',
      icon: Icon(Icons.refresh, size: compact ? 18 : 24),
      visualDensity: compact ? VisualDensity.compact : null,
      onPressed: _loadingHistory || _sending ? null : _loadHistory,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 620) {
              return Row(
                children: [
                  title,
                  const SizedBox(width: 20),
                  Expanded(child: search()),
                  const SizedBox(width: 10),
                  SizedBox(width: 200, child: filter()),
                  refresh(),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: search(compact: true)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: filter(compact: true)),
                refresh(compact: true),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        const Text('Messages sent or attempted from your account.'),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _historyCards() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in _history) {
      final batchId = row['batchId']?.toString() ?? '';
      final key = batchId.isEmpty
          ? 'single:${row['requestId']}'
          : 'batch:$batchId';
      (groups[key] ??= []).add(row);
    }
    final terms = _historySearch.text.trim().toLowerCase().split(
      RegExp(r'\s+'),
    );
    final visible = groups.values.where((group) {
      final date = DateTime.tryParse('${group.first['createdAt']}')?.toLocal();
      final month = _historyMonth;
      if (month != null &&
          (date?.month != month.month || date?.year != month.year)) {
        return false;
      }
      return group.any(
        (row) => terms.every(
          (term) => '${row['driverName'] ?? ''}'.toLowerCase().contains(term),
        ),
      );
    }).toList();
    if (visible.isEmpty) return const Text('No messages match these filters.');
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 780
            ? 3
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final group in visible)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.length == 1
                              ? '${group.first['driverName']}'
                              : 'Bulk SMS · ${group.length} recipients',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          _date(context, group.first['createdAt']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.sms_outlined, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${group.first['message']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (group.every(
                                    (row) => ['accepted', 'delivered'].contains(
                                      DriverSmsService.displayStatus(row),
                                    ),
                                  )) ...[
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: Color(0xFF18764A),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Flexible(
                                    child: Text(
                                      _groupStatus(group),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _viewHistoryMessage(context, group),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: const Text('View'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _groupStatus(List<Map<String, dynamic>> group) {
    final counts = <String, int>{};
    for (final row in group) {
      final label = _historyStatus(DriverSmsService.displayStatus(row));
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }
    if (counts.length == 1) return counts.keys.single;
    return counts.entries
        .map((e) => '${e.value} ${e.key.toLowerCase()}')
        .join(' · ');
  }

  Future<void> _viewHistoryMessage(
    BuildContext context,
    List<Map<String, dynamic>> group,
  ) {
    final row = group.first;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.length == 1 ? '${row['driverName']}' : 'Bulk SMS'),
        content: SingleChildScrollView(
          child: SelectableText(
            [
              '${row['senderName']} · ${_date(context, row['createdAt'])}',
              '',
              '${row['message']}',
              '',
              for (final recipient in group)
                '${recipient['driverName']} · ${recipient['phone']} · '
                    '${_historyStatus(DriverSmsService.displayStatus(recipient))}',
            ].join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _setDirectory(bool office) {
    if (_findOffice == office) return;
    setState(() {
      _findOffice = office;
      _search.clear();
    });
    if (office && !_officeLoaded) _loadOfficeStaff();
  }

  Widget _recipientList(bool locked) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            _recipients.length > 3 && constraints.maxWidth >= 600;
        final drivers = _recipients.values.toList(growable: false);
        final columns = twoColumns ? 2 : 1;
        final rowCount = (drivers.length + columns - 1) ~/ columns;
        Widget row(int index) {
          final first = index * columns;
          if (!twoColumns) return _recipientRow(drivers[first], locked);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _recipientRow(drivers[first], locked)),
              const SizedBox(width: 16),
              Expanded(
                child: first + 1 < drivers.length
                    ? _recipientRow(drivers[first + 1], locked)
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }

        if (drivers.length <= 6) {
          return Column(children: List.generate(rowCount, row));
        }
        return SizedBox(
          height: twoColumns ? 260 : 380,
          child: Scrollbar(
            controller: _recipientScroll,
            child: ListView.builder(
              controller: _recipientScroll,
              key: const PageStorageKey('sms-recipients'),
              primary: false,
              padding: EdgeInsets.zero,
              itemCount: rowCount,
              itemBuilder: (_, index) => row(index),
            ),
          ),
        );
      },
    );
  }

  Widget _recipientRow(AppUserModel driver, bool locked) {
    final id = driver.userId;
    final missing = driver.phoneNumber.trim().isEmpty;
    final phone = TextFormField(
      key: ValueKey(driver.phoneNumber),
      initialValue: _phones[id],
      enabled: !locked,
      readOnly: !missing,
      keyboardType: TextInputType.phone,
      onChanged: (value) => setState(() => _phones[id] = value),
      decoration: InputDecoration(
        labelText: driver.role == 'driver'
            ? 'Driver phone number'
            : 'Staff phone number',
        hintText: 'Enter a Ghana phone number',
        helperText: missing ? 'No number linked to this profile.' : null,
        helperMaxLines: 2,
      ),
    );
    final remove = IconButton(
      tooltip: 'Remove ${driver.fullName}',
      onPressed: locked
          ? null
          : () => setState(() {
              _recipients.remove(id);
              _phones.remove(id);
              _updateGreeting();
            }),
      icon: const Icon(Icons.close),
    );
    final name = Text(
      driver.fullName,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
    return Container(
      key: ValueKey(id),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(9),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 480) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15, right: 12),
                    child: name,
                  ),
                ),
                Expanded(flex: 2, child: phone),
                remove,
              ],
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: name),
                  remove,
                ],
              ),
              phone,
            ],
          );
        },
      ),
    );
  }

  String _date(BuildContext context, dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final locale = MaterialLocalizations.of(context);
    return '${locale.formatShortDate(date)} ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }
}
