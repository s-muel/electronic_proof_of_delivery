import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/smtp_settings.dart';
import '../utils/platform_flags.dart';

class SettingsService {
  static final _firestore = FirebaseFirestore.instance;
  static const _settingsCollection = 'appSettings';
  static const _smtpDocument = 'smtp';

  static const _smtpHostKey = 'smtp_host';
  static const _smtpPortKey = 'smtp_port';
  static const _smtpSslKey = 'smtp_ssl';
  static const _smtpIgnoreBadCertificateKey = 'smtp_ignore_bad_certificate';
  static const _senderEmailKey = 'sender_email';
  static const _senderPasswordKey = 'sender_password';
  static const _senderNameKey = 'sender_name';

  Future<SmtpSettings> loadSmtpSettings() async {
    final localSettings = await _loadLocalSmtpSettings();
    if (localSettings.isConfigured) return localSettings;

    if (!shouldUseFirestoreData) return localSettings;

    try {
      final cloudSettings = await _loadSmtpSettingsFromFirestore();
      if (cloudSettings != null) {
        await _saveLocalSmtpSettings(cloudSettings);
        return cloudSettings;
      }
    } catch (_) {
      // Keep using local/default settings when Firestore is unavailable.
    }

    return localSettings;
  }

  Future<SmtpSettings?> _loadSmtpSettingsFromFirestore() async {
    final snapshot = await _firestore
        .collection(_settingsCollection)
        .doc(_smtpDocument)
        .get();

    if (!snapshot.exists || snapshot.data() == null) return null;

    return SmtpSettings.fromMap(snapshot.data()!);
  }

  Future<void> refreshSmtpSettingsFromFirestore() async {
    if (!shouldUseFirestoreData) return;

    final settings = await _loadSmtpSettingsFromFirestore();
    if (settings == null) return;

    await _saveLocalSmtpSettings(settings);
  }

  Future<SmtpSettings> _loadLocalSmtpSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = SmtpSettings.defaults();

    return SmtpSettings(
      smtpHost: prefs.getString(_smtpHostKey) ?? defaults.smtpHost,
      smtpPort: prefs.getInt(_smtpPortKey) ?? defaults.smtpPort,
      smtpSsl: prefs.getBool(_smtpSslKey) ?? defaults.smtpSsl,
      ignoreBadCertificate:
          prefs.getBool(_smtpIgnoreBadCertificateKey) ??
          defaults.ignoreBadCertificate,
      senderEmail: prefs.getString(_senderEmailKey) ?? defaults.senderEmail,
      senderPassword:
          prefs.getString(_senderPasswordKey) ?? defaults.senderPassword,
      senderName: prefs.getString(_senderNameKey) ?? defaults.senderName,
    );
  }

  Future<void> saveSmtpSettings(SmtpSettings settings) async {
    if (shouldUseFirestoreData) {
      await _firestore
          .collection(_settingsCollection)
          .doc(_smtpDocument)
          .set(settings.toMap(), SetOptions(merge: true));
    }

    await _saveLocalSmtpSettings(settings);
  }

  Future<void> _saveLocalSmtpSettings(SmtpSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_smtpHostKey, settings.smtpHost.trim());
    await prefs.setInt(_smtpPortKey, settings.smtpPort);
    await prefs.setBool(_smtpSslKey, settings.smtpSsl);
    await prefs.setBool(
      _smtpIgnoreBadCertificateKey,
      settings.ignoreBadCertificate,
    );
    await prefs.setString(_senderEmailKey, settings.senderEmail.trim());
    await prefs.setString(_senderPasswordKey, settings.senderPassword);
    await prefs.setString(_senderNameKey, settings.senderName.trim());
  }
}
