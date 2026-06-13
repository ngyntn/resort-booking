import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // Wire up callback so the interceptor can trigger logout
    ApiClient.onUnauthorized = () {
      if (state.asData?.value == true) {
        state = const AsyncValue.data(false);
      }
    };
    final token = await ApiClient().getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> setLoggedIn(bool value) async {
    state = AsyncValue.data(value);
  }

  Future<void> logout() async {
    await ApiClient().clearTokens();
    state = const AsyncValue.data(false);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);
