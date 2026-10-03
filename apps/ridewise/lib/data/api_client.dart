import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => 'ApiException($status): $message';
}

abstract interface class TripApi {
  Future<RouteEstimate> estimateTrip(TripDraft draft);
}

/// Talks to apps/api. It is used only for route estimates; everything else runs on the phone.
class ApiClient implements TripApi {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:3000',
          );

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<RouteEstimate> estimateTrip(TripDraft draft) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/trips/estimate'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(draft.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Route estimate failed', status: response.statusCode);
    }
    return RouteEstimate.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }
}
