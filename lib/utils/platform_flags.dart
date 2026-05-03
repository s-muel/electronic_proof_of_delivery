import 'package:flutter/foundation.dart';

bool get shouldSkipAutomaticFirebaseRefresh {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
}

bool get shouldUseFirestoreData {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
      ? false
      : true;
}
