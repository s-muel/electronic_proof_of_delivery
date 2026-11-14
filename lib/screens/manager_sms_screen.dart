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
  bool _findOffice = false;
  List<AppUserModel> _officeStaff = [];
  bool _loadingOffice = false;
  bool _officeLoaded = false;
  String? _officeError;
  final _message = TextEditingController();
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
        final found = _history.map((r) => r['requestId']).toSet();
        final resolved = _retry.keys
            .where((id) => found.contains(_retry[id]!['requestId']))
            .toList();
        for (final id in resolved) {
          _retry.remove(id);
          _recipients.remove(id);
          _phones.remove(id);
        }
        if (resolved.isNotEmpty) {
          _result = 'Found ${resolved.length} attempt(s) in SMS history.';
          if (_recipients.isEmpty) _message.clear();
        }
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
        message.isEmpty ||
        message.length > 480 ||
        _recipients.isEmpty ||
        _recipients.keys.any((id) => _phones[id]!.trim().isEmpty)) {
      return;
    }
    setState(() => _sending = true);
    try {
      if (!_unconfirmed) {
        final rng = Random.secure();
        for (final id in _recipients.keys) {
          _retry[id] = {
            'requestId': List.generate(
              16,
              (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
            ).join(),
            'driverId': id,
            if (_recipients[id]!.role != 'driver') 'recipientType': 'office',
            'phone': _phones[id]!.trim(),
            'message': message,
          };
        }
      }

      var recorded = 0;
      final rejected = <String>[];
      final unconfirmedReasons = <String>{};
      for (final entry in _retry.entries.toList()) {
        final driverName = _recipients[entry.key]!.fullName;
        final data = entry.value;
        try {
          final record = _preview
              ? <String, dynamic>{
                  ...data,
                  'driverName': driverName,
                  'senderName': 'Preview manager',
                  'status': 'preview',
                  'createdAt': DateTime.now().toIso8601String(),
                  'detail': 'Recorded in preview mode. No SMS was sent.',
                }
              : (await DriverSmsService.request(data: data))['record']
                    as Map<String, dynamic>;
          if (!mounted) return;
          setState(() {
            _retry.remove(entry.key);
            _recipients.remove(entry.key);
            _phones.remove(entry.key);
            _history = [
              record,
              ..._history.where((r) => r['requestId'] != data['requestId']),
            ];
          });
          recorded++;
        } on SmsRejected catch (error) {
          if (!mounted) return;
          _retry.remove(entry.key);
          rejected.add('$driverName: ${error.message}');
        } catch (error) {
          if (!mounted) return;
          // Keep the original request ID so a retry cannot send it twice.
          unconfirmedReasons.add(_error(error));
        }
      }
      if (!mounted) return;
      setState(() {
        _result = [
          if (recorded > 0)
            '$recorded attempt(s) recorded. See SMS history for each result.',
          ...rejected,
          if (_unconfirmed)
            '${_retry.length} attempt(s) could not be confirmed. Retry checks only those attempts.',
          ...unconfirmedReasons,
        ].join('\n');
        if (_recipients.isEmpty) _message.clear();
      });
    } finally {
      if (mounted) setState(() => _sending = false);
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
                    onTap: (index) => setState(() => _tab = index),
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
                                                _message.text.trim().isEmpty
                                            ? null
                                            : _send,
                                        icon: Icon(
                                          _unconfirmed
                                              ? Icons.refresh
                                              : Icons.send_outlined,
                                        ),
                                        label: Text(
                                          _sending
                                              ? 'Working…'
                                              : _unconfirmed
                                              ? 'Check or retry same attempt'
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
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'SMS history',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Refresh history',
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _loadingHistory || _sending
                                      ? null
                                      : _loadHistory,
                                ),
                              ],
                            ),
                            const Text(
                              'Messages sent or attempted from your account.',
                            ),
                            if (_loadingHistory)
                              const LinearProgressIndicator(),
                            if (_historyError != null) Text(_historyError!),
                            if (!_loadingHistory &&
                                _historyError == null &&
                                _history.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('No SMS attempts yet.'),
                              ),
                            for (final row in _history)
                              Card(
                                child: ListTile(
                                  title: Text(
                                    '${row['driverName']} · ${row['phone']}',
                                  ),
                                  subtitle: Text(
                                    [
                                      '${row['message']}',
                                      '${row['senderName']} · ${_date(context, row['createdAt'])}',
                                      if ((row['detail'] as String? ?? '')
                                          .isNotEmpty)
                                        '${row['detail']}',
                                      if ((row['providerId'] as String? ?? '')
                                          .isNotEmpty)
                                        'Arkesel message ID: ${row['providerId']}',
                                    ].join('\n'),
                                  ),
                                  trailing: Chip(
                                    label: Text(switch (row['status']) {
                                      'accepted' => 'Accepted',
                                      'delivered' => 'Delivered',
                                      'not_delivered' => 'Not delivered',
                                      'preview' => 'Preview',
                                      'failed' => 'Failed',
                                      'unknown' => 'Unconfirmed',
                                      _ => 'Pending',
                                    }),
                                  ),
                                ),
                              ),
                            if (_cursor != null)
                              TextButton(
                                onPressed: _loadingHistory || _sending
                                    ? null
                                    : () => _loadHistory(more: true),
                                child: const Text('Load older messages'),
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
