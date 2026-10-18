import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'http://192.168.1.8:8080/api';

  Future<List<dynamic>> obtenerProyectos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/proyectos'),
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Error al obtener proyectos. '
      'Código: ${response.statusCode}',
    );
  }
}