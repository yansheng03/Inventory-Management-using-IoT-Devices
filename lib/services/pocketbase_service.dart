import 'dart:convert';
import 'package:http/http.dart' as http;

class PocketBaseService {
  final String baseUrl = "http://YOUR_POCKETBASE_IP:8090"; // e.g., http://192.168.1.5:8090

  Future<List<Map<String, dynamic>>> fetchProcessedResults() async {
    final url = Uri.parse('$baseUrl/api/collections/videos/records?filter=processed=true');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['items']);
    } else {
      throw Exception("Failed to fetch processed results");
    }
  }
}
