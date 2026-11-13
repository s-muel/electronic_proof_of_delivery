import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/app_user_model.dart';
import '../services/app_user_service.dart';

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

  Future<Map<String, dynamic>> _request({
    Map<String, String>? data,
    String? cursor,
  }) async {
    const base = String.fromEnvironment('SMS_FUNCTION_BASE_URL');
    if (base.isEmpty && !kIsWeb) {
      throw StateError('Driver SMS needs the BAJ server URL in this build.');
    }
    final origin = base.isEmpty
        ? Uri.base.origin
        : base.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse(
      '$origin/.netlify/functions/driver-sms',
    ).replace(queryParameters: cursor == null ? null : {'cursor': cursor});
    if (uri.scheme != 'https' &&
        uri.host != 'localhost' &&
        uri.host != '127.0.0.1') {
      throw StateError('Driver SMS needs a secure server URL.');
    }
    final token = await FirebaseAuth.instance.currentUser?.getIdToken().timeout(
      const Duration(seconds: 10),
    );
    if (token == null) throw StateError('Sign in again to use driver SMS.');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final client = http.Client();
    try {
      final response =
          await (data == null
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: jsonEncode(data)))
              .timeout(const Duration(seconds: 35));
      Map<String, dynamic> result;
      try {
        result = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw StateError(
          'The SMS endpoint returned an unexpected response (HTTP '
          '${response.statusCode}). Check that the BAJ SMS function is deployed.',
        );
      }
      if (response.statusCode != 200) {
        final reason =
            result['error']?.toString() ?? 'Driver SMS is unavailable.';
        if (response.statusCode < 500) throw _SmsRejected(reason);
        throw StateError(reason);
      }
      return result;
    } finally {
      client.close();
    }
  }

  String _error(Object error) => error is StateError
      ? error.message
      : 'Could not reach the service. Try again when connected.';

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
      final page = await _request(cursor: more ? _cursor : null);
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
        message.isEmpty ||
        message.length > 480 ||
        _recipients.isEmpty ||
        _recipients.keys.any((id) => _phones[id]!.trim().isEmpty)) {
      return;
    }
    setState(() => _sending = true);
    try {
      if (!_unconfirmed) {
        final names = _recipients.values
            .map((d) => '${d.fullName} · ${_phones[d.userId]!.trim()}')
            .join('\n');
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              _preview
                  ? 'Record preview SMS?'
                  : 'Send SMS to ${_recipients.length} drivers?',
            ),
            content: SingleChildScrollView(child: Text('$names\n\n$message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_preview ? 'Record preview' : 'Send SMS'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
        final rng = Random.secure();
        for (final id in _recipients.keys) {
          _retry[id] = {
            'requestId': List.generate(
              16,
              (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
            ).join(),
            'driverId': id,
            'phone': _phones[id]!.trim(),
            'message': message,
          };
        }
      }

      var recorded = 0;
      final rejected = <String>[];
      final unconfirmedReasons = <String>{};
      for (final entry in _retry.entries.toList()) {
        final driver = _recipients[entry.key]!;
        final data = entry.value;
        try {
          final record = _preview
              ? <String, dynamic>{
                  ...data,
                  'driverName': driver.fullName,
                  'senderName': 'Preview manager',
                  'status': 'preview',
                  'createdAt': DateTime.now().toIso8601String(),
                  'detail': 'Recorded in preview mode. No SMS was sent.',
                }
              : (await _request(data: data))['record'] as Map<String, dynamic>;
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
        } on _SmsRejected catch (error) {
          if (!mounted) return;
          _retry.remove(entry.key);
          rejected.add('${driver.fullName}: ${error.message}');
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
    final query = _search.text.trim().toLowerCase();
    final results = query.isEmpty
        ? <AppUserModel>[]
        : _drivers
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
                              'Add one or more drivers, review the job instructions and send an SMS.',
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
                                    const Text(
                                      'FIND DRIVERS',
                                      style: _sectionLabel,
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _search,
                                      enabled: !locked,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText:
                                            'Search driver by name or phone',
                                        prefixIcon: const Icon(Icons.search),
                                        suffixIcon: IconButton(
                                          tooltip: 'Refresh drivers',
                                          onPressed: locked || _loadingDrivers
                                              ? null
                                              : _loadDrivers,
                                          icon: const Icon(Icons.refresh),
                                        ),
                                      ),
                                    ),
                                    if (_loadingDrivers || _selectingAll)
                                      LinearProgressIndicator(
                                        semanticsLabel: _selectingAll
                                            ? 'Selecting all drivers'
                                            : 'Loading drivers',
                                      ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 8,
                                        children: [
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
                                    if (_driverError != null)
                                      Text(_driverError!),
                                    if (query.isNotEmpty &&
                                        !_loadingDrivers &&
                                        _driverError == null &&
                                        results.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text('No matching drivers.'),
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
                                          _sending || _selectingAll ||
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
                                              : 'Review SMS',
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
                                    ].join('\n'),
                                  ),
                                  trailing: Chip(
                                    label: Text(switch (row['status']) {
                                      'accepted' => 'Accepted',
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
        labelText: 'Driver phone number',
        hintText: 'Enter a Ghana phone number',
        helperText: missing
            ? 'No number linked to this driver’s profile.'
            : null,
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

class _SmsRejected extends StateError {
  _SmsRejected(super.message);
}
