import 'package:proyecto_ocr/features/selection_service/selection.service_page.dart';

/// Configuración del backend
class BackendConfig {
  // URL del backend - Cambiar según el entorno
  // Para desarrollo local: 'http://localhost:3000'
  // Para red local: 'http://192.168.X.X:3000' (reemplazar con tu IP)
  // IP Wi-Fi de la PC: 192.168.1.92
  static const String baseUrl = 'https://99c2-190-12-13-17.ngrok-free.app';

  // Endpoints
  static const String consultarServicioOCR = '/cloud/consultar-servicio-ocr';

  // URL completa
  static String get consultarServicioUrl => '$baseUrl$consultarServicioOCR';

  // Tipos de servicio disponibles
  static const List<String> serviceTypes = ['luz_loja', 'sri_matriculacion'];

  /// Mapea el enum ServiceType del frontend al string esperado por el backend
  static String getServiceTypeString(ServiceType service) {
    switch (service) {
      case ServiceType.luz:
        return 'luz_loja';
      case ServiceType.matriculacionVehicular:
        return 'sri_matriculacion';
      case ServiceType.ocr:
        return 'ocr_cedula';
      case ServiceType.multas:
        return 'ant_multas';
      case ServiceType.claroPlanes:
        return 'claro_planes';
      // ignore: unreachable_switch_default
      default:
        return 'desconocido';
    }
  }
}
