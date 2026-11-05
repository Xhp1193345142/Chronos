import 'package:shared_preferences/shared_preferences.dart';

const legacyManualKey = 'chronos_manual_entries_v1';

/// The controller validates payloads before any migration or write.
abstract class ManualRecordStore {
  Future<String?> read();
  Future<void> write(String payload);
  Future<void> finishLoad(String validatedPayload) async {}
  Future<void> close();
}

class PreferenceManualStore extends ManualRecordStore {
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(legacyManualKey);

  @override
  Future<void> write(String payload) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      legacyManualKey,
      payload,
    )) {
      throw StateError('Timer write failed');
    }
  }

  @override
  Future<void> close() async {}
}
