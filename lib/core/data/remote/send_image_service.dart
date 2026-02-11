import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Envía una imagen (en base64) y el tipo de servicio al backend.
/// [imageFile] es el archivo de imagen capturado.
/// [serviceType] es el tipo de servicio a consultar.
/// [backendUrl] es la URL de tu backend.
Future<http.Response> sendImageToBackend({
  File? imageFile,
  String? base64Image,
  String? base64ImageBack, // Imagen trasera opcional
  required String serviceType,
  required String backendUrl,
}) async {
  String? imageB64 = base64Image;
  if (imageB64 == null && imageFile != null) {
    final bytes = await imageFile.readAsBytes();
    imageB64 = base64Encode(bytes);
  }
  if (imageB64 == null) {
    throw ArgumentError('Se requiere imageFile o base64Image');
  }

  final Map<String, dynamic> bodyMap = {
    'base64Image': imageB64,
    'serviceType': serviceType,
  };

  // Agregar imagen trasera si existe
  if (base64ImageBack != null) {
    bodyMap['base64ImageBack'] = base64ImageBack;
  }

  final body = jsonEncode(bodyMap);
  final response = await http
      .post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
      .timeout(const Duration(seconds: 120)); // Aumentado a 120s para OCR
  return response;
}
