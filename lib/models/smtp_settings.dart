class SmtpSettings {
  final String smtpHost;
  final int smtpPort;
  final bool smtpSsl;
  final bool ignoreBadCertificate;
  final String senderEmail;
  final String senderPassword;
  final String senderName;

  const SmtpSettings({
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpSsl,
    required this.ignoreBadCertificate,
    required this.senderEmail,
    required this.senderPassword,
    required this.senderName,
  });

  factory SmtpSettings.defaults() {
    return const SmtpSettings(
      smtpHost: 'mail.bajfreight.com',
      smtpPort: 465,
      smtpSsl: true,
      ignoreBadCertificate: true,
      senderEmail: 'samuel.essuman@bajfreight.com',
      senderPassword: '',
      senderName: 'Samuel Simon Essuman',
    );
  }

  factory SmtpSettings.fromMap(Map<String, dynamic> map) {
    final defaults = SmtpSettings.defaults();

    return SmtpSettings(
      smtpHost: map['smtpHost'] ?? defaults.smtpHost,
      smtpPort: map['smtpPort'] ?? defaults.smtpPort,
      smtpSsl: map['smtpSsl'] ?? defaults.smtpSsl,
      ignoreBadCertificate:
          map['ignoreBadCertificate'] ?? defaults.ignoreBadCertificate,
      senderEmail: map['senderEmail'] ?? defaults.senderEmail,
      senderPassword: map['senderPassword'] ?? defaults.senderPassword,
      senderName: map['senderName'] ?? defaults.senderName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'smtpHost': smtpHost.trim(),
      'smtpPort': smtpPort,
      'smtpSsl': smtpSsl,
      'ignoreBadCertificate': ignoreBadCertificate,
      'senderEmail': senderEmail.trim(),
      'senderPassword': senderPassword,
      'senderName': senderName.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  bool get isConfigured {
    return smtpHost.trim().isNotEmpty &&
        smtpPort > 0 &&
        senderEmail.trim().isNotEmpty &&
        senderPassword.trim().isNotEmpty;
  }
}
