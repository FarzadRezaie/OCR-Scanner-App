import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Replace with your backend IP and port
  final String baseUrl = "http://localhost:3000";

  /// Upload document to backend
  Future<Map<String, dynamic>> uploadDocument({
    required String title,
    required String ocrText,
    File? file,
    Uint8List? bytes,
  }) async {
    try {
      var uri = Uri.parse("$baseUrl/upload");
      var request = http.MultipartRequest('POST', uri);

      request.fields['title'] = title;
      request.fields['ocrText'] = ocrText;

      // For mobile: attach file
      if (!kIsWeb && file != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      // For web: attach bytes as file
      if (kIsWeb && bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: "$title.png"),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "success": false,
          "message": "Server returned status ${response.statusCode}",
        };
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// Fetch all saved documents
  Future<List<Map<String, dynamic>>> fetchDocuments() async {
    try {
      var uri = Uri.parse("$baseUrl/documents");
      var response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
