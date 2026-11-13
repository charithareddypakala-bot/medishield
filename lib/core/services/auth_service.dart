import 'api_client.dart';
import 'medication_reminder_service.dart';

class AuthService {
  static Future<void> requestPasswordReset({required String email}) async {
    await ApiClient.instance.post(
      '/auth/forgot-password',
      body: {'email': email.trim().toLowerCase()},
      requireAuth: false,
    );
  }

  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await ApiClient.instance.post(
      '/auth/reset-password',
      body: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'newPassword': newPassword,
      },
      requireAuth: false,
    );
  }

  static Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.instance.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      requireAuth: false,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final userMap = Map<String, dynamic>.from(data['user'] ?? {});
    final user = AppUser.fromJson(userMap);
    final accessToken = (data['accessToken'] ?? '').toString();
    final refreshToken = (data['refreshToken'] ?? '').toString();

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const ApiException('Authentication response was invalid');
    }

    await AppSession.instance.saveSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return user;
  }

  static Future<AppUser> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final response = await ApiClient.instance.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      },
      requireAuth: false,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final userMap = Map<String, dynamic>.from(data['user'] ?? {});
    final user = AppUser.fromJson(userMap);
    final accessToken = (data['accessToken'] ?? '').toString();
    final refreshToken = (data['refreshToken'] ?? '').toString();

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const ApiException('Registration response was invalid');
    }

    await AppSession.instance.saveSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return user;
  }

  static Future<AppUser?> loadCurrentUser() async {
    final token = AppSession.instance.accessToken;
    if (token == null || token.isEmpty) {
      return null;
    }

    final response = await ApiClient.instance.get('/users/profile');
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final user = AppUser.fromJson(data);

    await AppSession.instance.saveSession(
      user: user,
      accessToken: token,
      refreshToken: AppSession.instance.refreshToken ?? '',
    );

    return user;
  }

  static Future<void> logout({bool returnToWelcome = false}) async {
    // The backend logout route does not revoke stateless JWTs. Clear the local
    // credentials directly so logout still works when the access token expired.
    await AppSession.instance.clear();
    if (returnToWelcome) AppSession.instance.onSessionExpired?.call();

    // Clearing local alarms is best effort and must not prevent the user from
    // leaving an authenticated screen after their session has expired.
    try {
      await MedicationReminderService.instance.syncMedicines(
        const [],
        enabled: false,
      );
    } catch (_) {
      // The next successful reminder sync will replace any stale alarms.
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ApiClient.instance.post(
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
