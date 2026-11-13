import 'api_client.dart';

class MediShieldRepository {
  MediShieldRepository._();

  static final ApiClient _api = ApiClient.instance;

  static Map<String, dynamic> _data(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] ?? {});

  static Future<Map<String, dynamic>> getProfile() async =>
      _data(await _api.get('/users/profile'));

  static Future<Map<String, dynamic>> getDashboard() async =>
      _data(await _api.get('/users/dashboard'));

  static Future<List<Map<String, dynamic>>> getMedicines({
    String search = '',
    int? slot,
  }) async {
    final query = <String, String>{'limit': '100'};
    if (search.trim().isNotEmpty) query['search'] = search.trim();
    if (slot != null) query['slot'] = '$slot';
    final response = await _api.get(
      '/medicines?${Uri(queryParameters: query).query}',
    );
    final data = _data(response);
    return (data['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createMedicine(
    Map<String, dynamic> body,
  ) async => _data(await _api.post('/medicines', body: body));

  static Future<Map<String, dynamic>> updateMedicine(
    String id,
    Map<String, dynamic> body,
  ) async => _data(await _api.put('/medicines/$id', body: body));

  static Future<void> deleteMedicine(String id) async {
    await _api.delete('/medicines/$id');
  }

  static Future<Map<String, dynamic>> assignMedicineSlot(
    String id,
    int? slot,
  ) async =>
      _data(await _api.patch('/medicines/$id/slot', body: {'slot': slot}));

  static Future<List<Map<String, dynamic>>> getTodayDoses() async {
    final data = _data(await _api.get('/doses/today'));
    return (data['events'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getDoseHistory({
    DateTime? date,
  }) async {
    final suffix = date == null ? '' : '?date=${date.toIso8601String()}';
    final response = await _api.get('/doses/history$suffix');
    final data = response['data'];
    return (data as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> confirmDose(String eventId) async =>
      _data(await _api.post('/doses/$eventId/confirm-taken'));

  static Future<Map<String, dynamic>> updateDoseStatus(
    String eventId,
    String status, {
    String? note,
  }) async => _data(
    await _api.patch(
      '/doses/$eventId/status',
      body: {'status': status, if (note != null) 'note': note},
    ),
  );

  static Future<Map<String, dynamic>> getSettings() async =>
      _data(await _api.get('/users/settings'));

  static Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settings,
  ) async => _data(await _api.patch('/users/settings', body: settings));

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profile,
  ) async => _data(await _api.put('/users/profile', body: profile));

  static Future<List<Map<String, dynamic>>> getPrescriptionHistory() async {
    final response = await _api.get('/prescriptions/history');
    return (response['data'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> uploadPrescription({
    required List<int> bytes,
    required String fileName,
  }) async => _data(
    await _api.postMultipart(
      '/prescriptions/upload',
      bytes: bytes,
      fileName: fileName,
    ),
  );

  static Future<List<Map<String, dynamic>>> confirmPrescription({
    required String scanId,
    required List<Map<String, dynamic>> medicines,
  }) async {
    final response = await _api.post(
      '/prescriptions/$scanId/confirm',
      body: {'medicines': medicines},
    );
    return ((response['data'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getCaretakerRequests() async {
    final response = await _api.get('/caretakers/requests');
    return (response['data'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getApprovedPatients() async {
    final response = await _api.get('/caretakers/approved-patients');
    return (response['data'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createCaretakerRequest({
    String? patientId,
    String? caretakerId,
    String? message,
  }) async => _data(
    await _api.post(
      '/caretakers/requests',
      body: {
        if (patientId != null) 'patientId': patientId,
        if (caretakerId != null) 'caretakerId': caretakerId,
        if (message != null) 'message': message,
      },
    ),
  );

  static Future<Map<String, dynamic>> updateCaretakerRequest(
    String id, {
    required bool approve,
  }) async => _data(
    await _api.patch(
      '/caretakers/requests/$id/${approve ? 'approve' : 'reject'}',
    ),
  );
}
