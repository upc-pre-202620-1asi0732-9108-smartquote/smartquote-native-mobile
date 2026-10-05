import 'package:dio/dio.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Ejemplo: Obtener token
    // final prefs = await SharedPreferences.getInstance();
    // final token = prefs.getString('access_token');
    
    // Para pruebas, asumimos un token estático o que el endpoint no lo requiere si estás probando
    String? token = "TU_TOKEN_JWT_AQUI"; 
    
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  // Aquí agregarías la lógica para interceptar un error 401 y llamar al endpoint /refresh
}