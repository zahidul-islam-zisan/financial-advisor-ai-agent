import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/agent_config.dart';
import '../error/failure.dart';

class AgentService {
  final http.Client _client;
  final FirebaseAuth? _auth;
  final String _baseUrl;
  final Future<String?> Function({bool forceRefresh})? _tokenProvider;

  AgentService({
    http.Client? client,
    FirebaseAuth? auth,
    String? baseUrl,
    Future<String?> Function({bool forceRefresh})? tokenProvider,
  })  : _client = client ?? http.Client(),
        _auth = auth,
        _baseUrl = baseUrl ?? AgentConfig.baseUrl,
        _tokenProvider = tokenProvider;

  FirebaseAuth get _effectiveAuth => _auth ?? FirebaseAuth.instance;

  /// Helper to get user Firebase ID token
  Future<String?> _getIdToken({bool forceRefresh = false}) async {
    final provider = _tokenProvider;
    if (provider != null) {
      return await provider(forceRefresh: forceRefresh);
    }
    final user = _effectiveAuth.currentUser;
    if (user == null) return null;
    return await user.getIdToken(forceRefresh);
  }

  /// Internal authenticated POST request with 45s timeout and automatic 401 retry
  Future<Either<Failure, Map<String, dynamic>>> _postWithAuth(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    String? token = await _getIdToken();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AgentService] No Firebase ID token available (user not logged in or null token).');
      }
      return Left(Failure("Please log in again"));
    }

    final cleanBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');
    final jsonPayload = jsonEncode(body);

    if (kDebugMode) {
      debugPrint('[AgentService] Request URL: $url');
    }

    http.Response response;
    try {
      response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonPayload,
          )
          .timeout(const Duration(seconds: 45));

      if (kDebugMode) {
        final preview = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        debugPrint('[AgentService] HTTP Status Code: ${response.statusCode}');
        debugPrint('[AgentService] Response Body (first 300 chars): $preview');
      }

      // Force refresh token once on 401 and retry
      if (response.statusCode == 401) {
        if (kDebugMode) {
          debugPrint('[AgentService] 401 Unauthorized received. Attempting token force-refresh & retry...');
        }
        final refreshedToken = await _getIdToken(forceRefresh: true);
        if (refreshedToken == null) {
          if (kDebugMode) {
            debugPrint('[AgentService] Token refresh returned null.');
          }
          return Left(Failure("Please log in again"));
        }

        response = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $refreshedToken',
              },
              body: jsonPayload,
            )
            .timeout(const Duration(seconds: 45));

        if (kDebugMode) {
          final preview = response.body.length > 300
              ? response.body.substring(0, 300)
              : response.body;
          debugPrint('[AgentService] Retry HTTP Status Code: ${response.statusCode}');
          debugPrint('[AgentService] Retry Response Body (first 300 chars): $preview');
        }
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('[AgentService] Caught TimeoutException: ${e.message}');
      }
      return Left(Failure("Request timed out. Please check your internet connection."));
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint('[AgentService] Caught SocketException: ${e.message} (osError: ${e.osError})');
      }
      return Left(Failure("Network error. Please check your internet connection."));
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('[AgentService] Caught http.ClientException: ${e.message}');
      }
      return Left(Failure("Network error. Please check your internet connection."));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AgentService] Caught Exception (${e.runtimeType}): $e');
      }
      return Left(Failure("Unable to connect to financial agent: ${e.toString()}"));
    }

    // Map HTTP Status Codes
    if (response.statusCode == 401) {
      return Left(Failure("Please log in again"));
    }

    if (response.statusCode == 429) {
      return Left(Failure("Too many requests, wait a minute"));
    }

    if (response.statusCode == 409) {
      return Left(Failure("This action was already processed"));
    }

    if (response.statusCode == 403) {
      return Left(Failure("You do not have permission to perform this action."));
    }

    if (response.statusCode == 410) {
      return Left(Failure("This pending action has expired. Please ask the AI to propose it again."));
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return Right(decoded);
        }
        return Left(Failure("Invalid response format from server."));
      } catch (_) {
        return Left(Failure("Invalid response format from server."));
      }
    }

    // Attempt to extract server error message if available
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] != null) {
        return Left(Failure(decoded['error'].toString()));
      }
    } catch (_) {}

    return Left(Failure("An unexpected error occurred (${response.statusCode}). Please try again."));
  }

  /// Send chat message to AI assistant
  Future<Either<Failure, Map<String, dynamic>>> sendMessage({
    required String message,
    List<Map<String, dynamic>> history = const [],
  }) async {
    return _postWithAuth(AgentConfig.chatEndpoint, {
      'message': message,
      'history': history,
    });
  }

  /// Confirm a Tier 2 pending financial action (budget or savings goal)
  Future<Either<Failure, Map<String, dynamic>>> confirm(String actionId) async {
    return _postWithAuth(AgentConfig.confirmEndpoint, {
      'actionId': actionId,
    });
  }

  /// Cancel a Tier 2 pending financial action
  Future<Either<Failure, Map<String, dynamic>>> cancel(String actionId) async {
    return _postWithAuth(AgentConfig.cancelEndpoint, {
      'actionId': actionId,
    });
  }
}
