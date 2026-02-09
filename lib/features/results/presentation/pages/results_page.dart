import 'package:flutter/material.dart';

import 'package:printing/printing.dart';
import 'package:proyecto_ocr/features/results/domain/entities/results_entities.dart';
import 'package:proyecto_ocr/features/results/services/pdf_generator_service.dart';

class ResultsScreen extends StatefulWidget {
  final List<dynamic> results; // Resultados del backend
  final VoidCallback onNewVerification;

  const ResultsScreen({
    super.key,
    required this.results,
    required this.onNewVerification,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int _selectedTab = 0;
  bool _isGeneratingPdf = false;

  Future<void> _sharePdfReport() async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final userData = _extractUserData();
      final servicesData = _processServicesData();
      final pendingPayments = _extractPendingPayments();

      final pdfBytes = await PdfGeneratorService().generateReport(
        userData: userData,
        services: servicesData,
        pendingPayments: pendingPayments,
      );

      await Printing.sharePdf(bytes: pdfBytes, filename: _getPdfFilename());
    } catch (e) {
      debugPrint('Error generando PDF: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  String _getMainServiceTitle() {
    if (widget.results.isEmpty) return 'RESULTADOS';
    final type = widget.results.first['serviceType'] as String?;
    if (type == null) return 'RESULTADOS';

    switch (type) {
      case 'luz_loja':
        return 'SERVICIO DE LUZ';
      case 'sri_matriculacion':
        return 'MATRICULACIÓN VEHICULAR';
      case 'ocr_cedula':
        return 'LECTURA DE CÉDULA';
      default:
        return 'DETALLE DE SERVICIO';
    }
  }

  String _getPdfFilename() {
    if (widget.results.isEmpty) return 'Resultado_Consulta.pdf';
    final type = widget.results.first['serviceType'] as String?;
    if (type == null) return 'Resultado_Consulta.pdf';

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    switch (type) {
      case 'luz_loja':
        return 'Resultado_Luz_Electrica_$dateStr.pdf';
      case 'sri_matriculacion':
        return 'Resultado_Matriculacion_Vehicular_$dateStr.pdf';
      case 'ocr_cedula':
        return 'Resultado_Lectura_Cedula_$dateStr.pdf';
      case 'claro_planes':
        return 'Resultado_Planes_Claro_$dateStr.pdf';
      case 'ant_multas':
        return 'Resultado_Multas_Transito_$dateStr.pdf';
      default:
        return 'Resultado_Consulta_$dateStr.pdf';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = _extractUserData();
    final servicesData = _processServicesData();
    final pendingPayments = _extractPendingPayments();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(userData),
            if (servicesData.length > 1) _buildTabBar(),
            Expanded(
              child: servicesData.length == 1
                  ? _buildSingleServiceView(servicesData.first, pendingPayments)
                  : (_selectedTab == 0
                        ? _buildServicesTab(servicesData)
                        : _buildPendingPaymentsTab(pendingPayments)),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // Extraer datos del usuario del primer resultado exitoso
  Map<String, String> _extractUserData() {
    final now = DateTime.now();
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    String nombre = 'Resultados';
    String cedula = '';
    String placa = '';

    for (var result in widget.results) {
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final serviceType = result['serviceType'] ?? '';

        // Para matriculación vehicular, buscar placa
        if (serviceType == 'sri_matriculacion') {
          if (data['placa'] != null && data['placa'].toString().isNotEmpty) {
            placa = data['placa'].toString();
          }
        } else {
          // Para otros servicios, verificar si es placa o cédula según tipo_detectado
          if (data['identificacion_detectada'] != null &&
              data['identificacion_detectada'].toString().isNotEmpty) {
            final tipoDetectado = data['tipo_detectado']?.toString() ?? '';
            final identificacion = data['identificacion_detectada'].toString();

            if (tipoDetectado == 'placa') {
              placa = identificacion;
            } else if (tipoDetectado == 'numero') {
              // Para Claro, solo guardamos el número
              cedula = identificacion;
            } else {
              cedula = identificacion;
            }
          }

          // Buscar nombre en datos del servicio
          // SKIP para claro_planes ya que solo retorna texto plano
          if (serviceType != 'claro_planes' && data['datos_servicio'] != null) {
            final datosServicio = data['datos_servicio'];
            if (datosServicio is Map &&
                datosServicio['contribuyente'] != null) {
              final contribuyente = datosServicio['contribuyente'];

              if (contribuyente is List && contribuyente.length > 1) {
                // Si es lista, el nombre suele estar en la posición 1
                nombre = contribuyente[1].toString();
              } else if (contribuyente is Map &&
                  contribuyente['nombre'] != null &&
                  contribuyente['nombre'].toString().isNotEmpty) {
                nombre = contribuyente['nombre'].toString();
              }
            }
          }

          // MEJORA: Si el nombre viene censurado (con asteriscos *) o es "Usuario"
          // Intentar extraerlo del OCR
          if ((nombre == 'Usuario' || nombre.contains('*')) &&
              data['texto_detectado'] != null) {
            final textoOCR = data['texto_detectado'].toString();
            final nombreOCR = _extractNameFromOCR(textoOCR);
            if (nombreOCR != 'Usuario') {
              nombre = nombreOCR;
            }
          }
        }

        if ((nombre != 'Usuario' &&
                !nombre.contains('*') &&
                cedula.isNotEmpty) ||
            placa.isNotEmpty) {
          break;
        }
      }
    }

    return {
      'name': nombre,
      'idNumber': cedula,
      'placa': placa,
      'verificationDate':
          '${now.day.toString().padLeft(2, '0')} de ${months[now.month - 1]}, ${now.year}',
    };
  }

  // Extraer nombre completo del texto OCR de la cédula
  String _extractNameFromOCR(String ocrText) {
    try {
      // Debug: ver el texto recibido
      // debugPrint('[DEBUG OCR] Texto recibido: \${ocrText.substring(0, ocrText.length > 200 ? 200 : ocrText.length)}');

      // Buscar patrón de apellidos y nombres en cédulas ecuatorianas
      final lines = ocrText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      String apellidos = '';
      String nombres = '';

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineUpper = line.toUpperCase();

        // Buscar línea "APELLIDOS" y capturar las siguientes no-vacías
        if (lineUpper.contains('APELLIDOS')) {
          int nextIndex = i + 1;
          List<String> apellidosList = [];

          // Capturar hasta 2 líneas después que no sean etiquetas
          while (nextIndex < lines.length && apellidosList.length < 2) {
            final siguiente = lines[nextIndex].trim();
            final siguienteUpper = siguiente.toUpperCase();

            // Skip si es otra etiqueta
            if (!siguienteUpper.contains('CONDICIÓN') &&
                !siguienteUpper.contains('NOMBRES') &&
                !siguienteUpper.contains('NACIONALIDAD') &&
                siguiente.isNotEmpty) {
              apellidosList.add(siguiente);
            }

            // Stop si encontramos NOMBRES
            if (siguienteUpper.contains('NOMBRES')) break;

            nextIndex++;
          }

          apellidos = apellidosList.join(' ').trim();
          // debugPrint('[DEBUG OCR] Apellidos encontrados: \$apellidos');
        }

        // Buscar línea "NOMBRES" y capturar la siguiente
        if (lineUpper.contains('NOMBRES')) {
          int nextIndex = i + 1;

          while (nextIndex < lines.length) {
            final siguiente = lines[nextIndex].trim();
            final siguienteUpper = siguiente.toUpperCase();

            // Skip etiquetas y líneas vacías
            if (!siguienteUpper.contains('NACIONALIDAD') &&
                !siguienteUpper.contains('CONDICIÓN') &&
                !siguienteUpper.contains('FECHA') &&
                siguiente.isNotEmpty &&
                !siguiente.contains('861122')) {
              // Skip números extraños
              nombres = siguiente;
              // debugPrint('[DEBUG OCR] Nombres encontrados: \$nombres');
              break;
            }

            nextIndex++;
          }
        }
      }

      // Combinar apellidos y nombres
      if (apellidos.isNotEmpty && nombres.isNotEmpty) {
        final nombreCompleto = '$apellidos $nombres'.trim();
        // debugPrint('[DEBUG OCR] Nombre completo: \$nombreCompleto');
        return nombreCompleto;
      } else {
        // debugPrint('[DEBUG OCR] No se encontraron apellidos o nombres');
      }
    } catch (e) {
      // debugPrint('[DEBUG OCR] Error en extracción: \$e');
    }

    return 'Usuario';
  }

  // Procesar datos de servicios
  List<ServiceData> _processServicesData() {
    List<ServiceData> services = [];

    for (var result in widget.results) {
      final serviceType = result['serviceType'] ?? 'desconocido';
      final success = result['success'] ?? false;
      final data = result['data'];
      final error = result['error'];
      final message = result['message'];

      services.add(
        ServiceData(
          type: serviceType,
          success: success,
          data: data,
          error: error?.toString(),
          message: message?.toString(),
        ),
      );
    }

    return services;
  }

  // Extraer pagos pendientes de los servicios
  List<PendingPayment> _extractPendingPayments() {
    List<PendingPayment> payments = [];

    for (var result in widget.results) {
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final serviceType = result['serviceType'] ?? '';

        // Skip para claro_planes ya que no tiene estructura de pagos
        if (serviceType == 'claro_planes') {
          continue;
        }

        final deuda = _extractAmount(data);
        if (deuda != null && deuda > 0) {
          payments.add(
            PendingPayment(
              id: serviceType,
              title: _getServiceTitle(serviceType),
              icon: _getServiceIcon(serviceType),
              amount: '\$${deuda.toStringAsFixed(2)}',
              dueDate: _extractDueDate(data),
              status: _isOverdue(data) ? 'overdue' : 'pending',
              serviceType: serviceType,
            ),
          );
        }
      }
    }

    return payments;
  }

  double? _extractAmount(dynamic data) {
    if (data == null) return null;

    // Buscar en datos_servicio primero
    if (data['datos_servicio'] != null) {
      final datosServicio = data['datos_servicio'];

      // Si no es un mapa (ej: Claro devuelve String), retornar null
      if (datosServicio is! Map) return null;

      // 1. Para servicios con estructura "deuda" (Luz/EERSSA)
      if (datosServicio['deuda'] != null) {
        final dynamic deuda = datosServicio['deuda'];

        // Manejo seguro de Mapa
        if (deuda is Map) {
          // Verificar si tiene deuda
          if (deuda['tieneDeuda'] == false) return 0.0;

          // Buscar montoTotal en el objeto deuda
          if (deuda['montoTotal'] != null) {
            try {
              return double.parse(
                deuda['montoTotal'].toString().replaceAll(
                  RegExp(r'[^\d.]'),
                  '',
                ),
              );
            } catch (e) {
              // Continuar buscando
            }
          }

          // EERSSA scraping devuelve llaves como "Deuda Total"
          // Buscar keys que contengan "Total" o "Monto"
          for (var key in deuda.keys) {
            if (key.toString().toLowerCase().contains('total')) {
              try {
                return double.parse(
                  deuda[key].toString().replaceAll(RegExp(r'[^\d.]'), ''),
                );
              } catch (e) {
                // Ignorar error al parsear
              }
            }
          }
        }
      }

      // 2. Para servicios con array "servicios" (Agua/Predio)
      if (datosServicio['servicios'] is List) {
        final servicios = datosServicio['servicios'] as List;
        double total = 0.0;
        for (var servicio in servicios) {
          if (servicio['valorTotal'] != null) {
            try {
              total += double.parse(
                servicio['valorTotal'].toString().replaceAll(
                  RegExp(r'[^\d.]'),
                  '',
                ),
              );
            } catch (e) {
              continue;
            }
          }
        }
        if (total > 0) return total;
      }

      // 3. Para SRI (totalPagar)
      if (datosServicio['totalPagar'] != null) {
        try {
          return double.parse(
            datosServicio['totalPagar'].toString().replaceAll(
              RegExp(r'[^\d.]'),
              '',
            ),
          );
        } catch (e) {
          // Continuar con otros campos
        }
      }

      // 4. Buscar en campos genéricos (fallback)
      final fields = [
        'total_deuda',
        'deuda',
        'total',
        'totalAPagar',
        'monto',
        'valor',
        'saldo',
      ];
      for (var field in fields) {
        if (datosServicio[field] != null) {
          try {
            return double.parse(
              datosServicio[field].toString().replaceAll(RegExp(r'[^\d.]'), ''),
            );
          } catch (e) {
            continue;
          }
        }
      }
    }

    return null;
  }

  String _extractDueDate(dynamic data) {
    if (data == null) return 'No especificado';

    if (data['datos_servicio'] != null) {
      final datosServicio = data['datos_servicio'];

      // Si no es un mapa, retornar valor por defecto
      if (datosServicio is! Map) return 'No especificado';

      final dateFields = [
        'fecha_vencimiento',
        'fechaVencimiento',
        'vencimiento',
        'fecha',
      ];
      for (var field in dateFields) {
        if (datosServicio[field] != null &&
            datosServicio[field].toString().isNotEmpty) {
          return datosServicio[field].toString();
        }
      }
    }

    return 'No especificado';
  }

  bool _isOverdue(dynamic data) {
    return false;
  }

  String _getServiceTitle(String type) {
    switch (type) {
      case 'luz_loja':
        return 'Servicio de Luz Eléctrica';
      case 'agua_loja':
        return 'Servicio de Agua Potable';
      case 'eerssa':
        return 'EERSSA - Empresa Eléctrica';
      case 'predio_urbano':
        return 'Impuesto Predial Urbano';
      case 'sri_matriculacion':
        return 'Matriculación Vehicular';
      case 'ant_multas':
        return 'Multas de Tránsito ANT';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getServiceIcon(String type) {
    switch (type) {
      case 'luz_loja':
        return Icons.bolt_outlined;
      case 'agua_loja':
        return Icons.water_drop_outlined;
      case 'eerssa':
        return Icons.electric_bolt_outlined;
      case 'predio_urbano':
        return Icons.home_work_outlined;
      case 'sri_matriculacion':
        return Icons.directions_car_outlined;
      case 'ant_multas':
        return Icons.traffic_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Widget _buildHeader(Map<String, String> userData) {
    final hasErrors = widget.results.any((r) => r['success'] == false);
    final allSuccessful = widget.results.every((r) => r['success'] == true);
    final isVehicle = userData['placa']!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nuevo: Indicador del Servicio
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getMainServiceTitle().toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Botón Compartir PDF
              if (allSuccessful)
                InkWell(
                  onTap: _sharePdfReport,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.share_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: allSuccessful
                            ? Colors.green[50]
                            : (hasErrors
                                  ? Colors.orange[50]
                                  : Colors.green[50]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        allSuccessful
                            ? Icons.check_circle
                            : (hasErrors
                                  ? Icons.warning_amber
                                  : Icons.check_circle),
                        size: 16,
                        color: allSuccessful
                            ? Colors.green[700]
                            : (hasErrors
                                  ? Colors.orange[700]
                                  : Colors.green[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        allSuccessful
                            ? 'Consulta completada'
                            : 'Consulta con advertencias',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: allSuccessful
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isVehicle)
            Text(
              userData['name']!,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              'Vehículo ${userData['placa']}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (userData['idNumber']!.isNotEmpty)
                _buildInfoChip(
                  Icons.badge_outlined,
                  'Cédula: ${userData['idNumber']}',
                ),
              if (userData['placa']!.isNotEmpty)
                _buildInfoChip(
                  Icons.local_shipping_outlined,
                  'Placa: ${userData['placa']}',
                ),
              _buildInfoChip(
                Icons.calendar_today_outlined,
                userData['verificationDate']!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              index: 0,
              icon: Icons.search,
              label: 'Detalles',
              isSelected: _selectedTab == 0,
            ),
          ),
          Expanded(
            child: _buildTab(
              index: 1,
              icon: Icons.receipt_long_outlined,
              label: 'Valores pendientes',
              isSelected: _selectedTab == 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.black : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.black : const Color(0xFF6B7280),
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Vista para cuando solo hay un servicio consultado
  Widget _buildSingleServiceView(
    ServiceData service,
    List<PendingPayment> payments,
  ) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildServiceDetailCard(service),
        if (payments.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildPendingPaymentSection(payments.first),
        ],
      ],
    );
  }

  Widget _buildServicesTab(List<ServiceData> services) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...services.asMap().entries.map((entry) {
          final index = entry.key;
          final service = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < services.length - 1 ? 12 : 0,
            ),
            child: _buildServiceCard(service),
          );
        }),
      ],
    );
  }

  Widget _buildPendingPaymentsTab(List<PendingPayment> payments) {
    if (payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡No hay valores pendientes!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.green[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'No se encontraron deudas pendientes',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...payments.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < payments.length - 1 ? 16 : 0,
            ),
            child: _buildPaymentCard(payment),
          );
        }),
      ],
    );
  }

  // Card detallado para un solo servicio
  Widget _buildServiceDetailCard(ServiceData service) {
    if (!service.success) {
      return _buildErrorCard(service);
    }

    switch (service.type) {
      case 'luz_loja':
        return _buildLuzCard(service);
      case 'eerssa':
        return _buildEerssaCard(service);
      case 'sri_matriculacion':
        return _buildMatriculacionCard(service);
      case 'ocr_cedula':
        return _buildOcrCard(service);
      case 'ant_multas':
        return _buildAntCard(service);
      case 'claro_planes':
        return _buildClaroCard(service);
      default:
        return _buildGenericCard(service);
    }
  }

  Widget _buildOcrCard(ServiceData service) {
    if (service.data == null) return _buildGenericCard(service);

    final datos = service.data!['datos_servicio'];
    final ocrFrontal = service.data!['texto_detectado'] ?? '';
    final ocrReverso = datos != null && datos is Map
        ? (datos['ocr_reverso'] ?? '')
        : '';

    final textFront = ocrFrontal.toString();
    final textBack = ocrReverso.toString();

    // --- EXTRACCIÓN FRONTAL ---
    final cedula = service.data!['identificacion_detectada'] ?? 'N/A';
    // Nombre ya extraído, pero podemos pulirlo
    final nombre = _extractNameFromOCR(textFront);

    // Nacionalidad
    String nacionalidad = _extractField(textFront, ['NACIONALIDAD']);
    // Fechas
    String fechaNac = _extractField(textFront, [
      'FECHA DE NACIMIENTO',
      'FECHA NACIMIENTO',
    ]);
    String fechaVen = _extractField(textFront, [
      'FECHA DE VENCIMIENTO',
      'VENCIMIENTO',
    ]);
    // Lugar
    String lugarNac = _extractFieldMultiLine(textFront, [
      'LUGAR DE NACIMIENTO',
    ], 2); // A veces son 2 líneas
    // Sexo
    String sexo = _extractField(textFront, ['SEXO']);
    // No Documento
    String noDoc = _extractField(textFront, ['No. DOCUMENTO', 'DOCUMENTO']);

    // --- EXTRACCIÓN REVERSO ---
    String padre = _extractFieldMultiLine(textBack, [
      'NOMBRES DEL PADRE',
      'DEL PADRE',
    ], 1);
    String madre = _extractFieldMultiLine(textBack, [
      'NOMBRES DE LA MADRE',
      'DE LA MADRE',
    ], 1);
    String estadoCivil = _extractField(textBack, [
      'ESTADO CIVIL',
      'ESTADO CML',
      'ESTADO',
    ]);
    String conyuge = _extractFieldMultiLine(textBack, [
      'CONYUGE',
      'CONVIVIENTE',
    ], 1);
    String donante = _extractField(textBack, ['DONANTE']);
    // Limpieza básica
    if (donante.length > 2) donante = donante.substring(0, 2); // "SI" o "NO"

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo[200]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOcrHeader(),
          const SizedBox(height: 24),

          _buildSectionTitle("INFORMACIÓN PERSONAL"),
          _buildInfoRow('Cédula', cedula.toString()),
          _buildDivider(),
          _buildInfoRow('Nombre', nombre),
          _buildDivider(),
          _buildInfoRow('Nacionalidad', nacionalidad),
          _buildDivider(),
          _buildInfoRow('Sexo', sexo),
          _buildDivider(),
          _buildInfoRow('Fecha Nacimiento', fechaNac),
          if (lugarNac != 'N/A') ...[
            _buildDivider(),
            _buildInfoRow('Lugar Nacimiento', lugarNac),
          ],

          const SizedBox(height: 24),
          _buildSectionTitle("DATOS DE FILIACIÓN Y ESTADO CIVIL"),
          if (padre != 'N/A') ...[
            _buildInfoRow('Padre', padre),
            _buildDivider(),
          ],
          if (madre != 'N/A') ...[
            _buildInfoRow('Madre', madre),
            _buildDivider(),
          ],
          _buildInfoRow('Estado Civil', estadoCivil),
          if (donante != 'N/A') ...[
            _buildDivider(),
            _buildInfoRow('Donante', donante),
          ],
          if (conyuge != 'N/A') ...[
            _buildDivider(),
            _buildInfoRow('Cónyuge', conyuge),
          ],

          if (fechaVen != 'N/A' || noDoc != 'N/A') ...[
            const SizedBox(height: 24),
            _buildSectionTitle("DETALLES DEL DOCUMENTO"),
            if (noDoc != 'N/A') ...[
              _buildInfoRow('No. Documento', noDoc),
              if (fechaVen != 'N/A') _buildDivider(),
            ],
            if (fechaVen != 'N/A') _buildInfoRow('Vence', fechaVen),
          ],

          const SizedBox(height: 24),
          _buildOcrFooter(),
        ],
      ),
    );
  }

  Widget _buildOcrHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.fingerprint, size: 32, color: Colors.indigo[800]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cédula de Identidad',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Registro Civil - Ecuador',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.indigo[300],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildOcrFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.indigo[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Datos extraídos automáticamente. Verifique con el documento físico.",
              style: TextStyle(fontSize: 12, color: Colors.indigo[900]),
            ),
          ),
        ],
      ),
    );
  }

  // Extrae valor buscando keyword hasta el salto de linea, ignorando basura
  String _extractField(String text, List<String> keywords) {
    if (text.isEmpty) return 'N/A';
    final lines = text.split('\n').map((l) => l.trim()).toList();

    for (int i = 0; i < lines.length; i++) {
      final lineUpper = lines[i].toUpperCase();
      for (var keyword in keywords) {
        if (lineUpper.contains(keyword)) {
          // Caso 1: Valor en la misma línea con ":" o espacio
          // "FECHA DE NACIMIENTO 22 NOV 1986"
          String val = lines[i]
              .substring(lineUpper.indexOf(keyword) + keyword.length)
              .trim();
          // Limpiar caracteres sucios iniciales like ":" o "."
          val = val.replaceAll(RegExp(r'^[:\.\-\s]+'), '');

          if (val.length > 2) {
            return val; // Encontramos algo util en la misma linea
          }

          // Caso 2: Buscar en lineas siguientes (hasta 4)
          // "NACIONALIDAD" (i) -> "33333" (i+1) -> "NUI..." (i+2) -> "ECUATORIANA" (i+3)
          int lookAhead = 1;
          while (lookAhead <= 4 && (i + lookAhead) < lines.length) {
            String candidate = lines[i + lookAhead].trim();
            if (_isLabel(candidate)) break; // Stop if hitting another label

            // Filtros de ruido:
            // - Solo números
            // - Empieza con NUI
            // - Muy corto
            final isOnlyNumbers = RegExp(r'^[0-9\.]+$').hasMatch(candidate);
            final isNUI = candidate.toUpperCase().startsWith('NUI');

            if (candidate.isNotEmpty &&
                !isOnlyNumbers &&
                !isNUI &&
                candidate.length > 2) {
              return candidate;
            }
            lookAhead++;
          }
        }
      }
    }
    return 'N/A';
  }

  // Extrae multiples lineas (para nombres padres o lugar nac)
  String _extractFieldMultiLine(
    String text,
    List<String> keywords,
    int linesToTake,
  ) {
    if (text.isEmpty) return 'N/A';
    final lines = text.split('\n').map((l) => l.trim()).toList();

    for (int i = 0; i < lines.length; i++) {
      final lineUpper = lines[i].toUpperCase();
      for (var keyword in keywords) {
        if (lineUpper.contains(keyword)) {
          List<String> result = [];
          int taken = 0;
          int current = i + 1;

          while (taken < linesToTake && current < lines.length) {
            String val = lines[current].trim();
            if (val.isNotEmpty && !_isLabel(val)) {
              result.add(val);
              taken++;
            } else if (_isLabel(val)) {
              break; // Chocamos con otra etiqueta
            }
            current++;
          }

          if (result.isNotEmpty) return result.join(' ');
        }
      }
    }
    return 'N/A';
  }

  bool _isLabel(String text) {
    final t = text.toUpperCase();
    return t.contains('FECHA') ||
        t.contains('LUGAR') ||
        t.contains('NOMBRE') ||
        t.contains('APELLIDO') ||
        t.contains('NACIONALIDAD') ||
        t.contains('SEXO') ||
        t.contains('ESTADO') ||
        t.contains('DONANTE') ||
        t.contains('INSTRUCCION');
  }

  Widget _buildAntCard(ServiceData service) {
    // El backend envuelve la respuesta ANT en 'datos_servicio'
    final datosServicio = service.data?['datos_servicio'];
    if (datosServicio == null) return _buildGenericCard(service);

    final nombre = datosServicio['nombre']?.toString() ?? 'N/A';
    final puntos = datosServicio['puntos']?.toString() ?? '0';
    final resumen = datosServicio['resumen'] as Map<dynamic, dynamic>?;
    final infracciones = datosServicio['infracciones'] as List<dynamic>?;

    // Extraer total de valores pendientes
    String totalPendiente = '\$ 0,00';
    if (resumen != null && resumen['total'] != null) {
      totalPendiente = resumen['total'].toString();
    }

    final hasMultas = infracciones != null && infracciones.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasMultas ? Colors.orange[200]! : Colors.green[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: hasMultas ? Colors.orange[50] : Colors.green[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.traffic_outlined,
                    color: hasMultas ? Colors.orange[700] : Colors.green[700],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ANT - Multas de Tránsito',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: hasMultas
                              ? Colors.orange[900]
                              : Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nombre,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Puntos (solo mostrar si tiene puntos)
                if (puntos != '0' && puntos.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.star_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Puntos de licencia: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        puntos,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                ],

                if (hasMultas) ...[
                  const SizedBox(height: 16),

                  // Total Pendiente
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Pendiente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          totalPendiente,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Resumen de valores
                  if (resumen != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Resumen de Valores',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (resumen['pendiente'] != null)
                      _buildInfoRow(
                        'Valor Pendiente',
                        resumen['pendiente'].toString(),
                      ),
                    const SizedBox(height: 12),
                    if (resumen['convenio'] != null)
                      _buildInfoRow(
                        'Valor Convenio',
                        resumen['convenio'].toString(),
                      ),
                    if (resumen['intereses'] != null)
                      _buildInfoRow(
                        'Intereses',
                        resumen['intereses'].toString(),
                      ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Tabla de Infracciones
                  Text(
                    'Infracciones (${infracciones.length})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...infracciones.map((infraccion) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '# Infracción: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            infraccion['infraccion']
                                                ?.toString() ??
                                            'N/A',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.red[900],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (infraccion['sancion'] != null &&
                                      infraccion['sancion']
                                          .toString()
                                          .trim()
                                          .isNotEmpty)
                                    Text(
                                      infraccion['sancion'].toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  Text(
                                    infraccion['total']?.toString() ??
                                        '\$ 0,00',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Citación: ${infraccion['citacion']?.toString() ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (infraccion['sancion'] != null &&
                              infraccion['sancion']
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                            Text(
                              'Sanción: ${infraccion['sancion'].toString()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[800],
                              ),
                            ),
                          Text(
                            'Fecha: ${infraccion['fecha']?.toString() ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (infraccion['entidad'] != null)
                            Text(
                              'Entidad: ${infraccion['entidad'].toString()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No se encontraron multas pendientes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuzCard(ServiceData service) {
    final data = service.data?['datos_servicio'];
    if (data == null) return _buildGenericCard(service);

    dynamic contribuyente = data['contribuyente'];
    final deuda = _extractAmount(service.data);

    String nombre = 'N/A';
    String direccion = 'N/A';
    String cuenta = 'N/A';
    String provincia = 'N/A';
    String canton = 'N/A';
    String parroquia = 'N/A';

    // Manejo robusto: EERSSA devuelve una Lista (Scraping) no un Map
    if (contribuyente is List && contribuyente.isNotEmpty) {
      // índices inferidos: [0] Cuenta, [1] Nombre(censurado), [2] Dirección, [3] Provincia, [4] Cantón, [5] Parroquia
      cuenta = contribuyente.isNotEmpty ? contribuyente[0].toString() : 'N/A';
      // SKIP nombre censurado en índice 1
      direccion = contribuyente.length > 2
          ? contribuyente[2].toString()
          : 'N/A';
      provincia = contribuyente.length > 3
          ? contribuyente[3].toString()
          : 'N/A';
      canton = contribuyente.length > 4 ? contribuyente[4].toString() : 'N/A';
      parroquia = contribuyente.length > 5
          ? contribuyente[5].toString()
          : 'N/A';
    } else if (contribuyente is Map) {
      direccion = contribuyente['direccion']?.toString() ?? 'N/A';
      cuenta = data['cuenta_numero']?.toString() ?? 'N/A';
      provincia = contribuyente['provincia']?.toString() ?? 'N/A';
      canton = contribuyente['canton']?.toString() ?? 'N/A';
      parroquia = contribuyente['parroquia']?.toString() ?? 'N/A';
    }

    // DEBUG: Ver qué datos tenemos disponibles
    // print('[DEBUG LUZ] service.data keys: \${service.data?.keys.toList()}');
    // print('[DEBUG LUZ] Tiene texto_detectado? \${service.data?.containsKey('texto_detectado')}');

    // Extraer nombre del OCR en lugar del scraping (viene censurado)
    if (service.data != null) {
      if (service.data!.containsKey('texto_detectado')) {
        // print('[DEBUG LUZ] Llamando a _extractNameFromOCR...');
        nombre = _extractNameFromOCR(
          service.data!['texto_detectado'].toString(),
        );
      } else {
        // print('[DEBUG LUZ] No se encontró texto_detectado en service.data');
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: deuda != null && deuda > 0
              ? Colors.orange[200]!
              : Colors.green[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bolt_outlined,
                  size: 32,
                  color: Colors.yellow[800],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Servicio de Luz Eléctrica',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Empresa Eléctrica - Loja',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Titular', nombre),
          _buildDivider(),
          _buildInfoRow('Cuenta N°', cuenta),
          _buildDivider(),
          _buildInfoRow('Dirección', direccion),
          _buildDivider(),
          _buildInfoRow('Provincia', provincia),
          _buildDivider(),
          _buildInfoRow('Cantón', canton),
          _buildDivider(),
          _buildInfoRow('Parroquia', parroquia),
          if (deuda != null && deuda > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valor pendiente de pago',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${deuda.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sin valores pendientes de pago',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEerssaCard(ServiceData service) {
    final data = service.data?['datos_servicio'];
    if (data == null) return _buildGenericCard(service);

    dynamic contribuyente = data['contribuyente'];
    final deuda = _extractAmount(service.data);

    String nombre = 'N/A';
    String direccion = 'N/A';
    String cuenta = 'N/A';

    if (contribuyente is List && contribuyente.isNotEmpty) {
      cuenta = contribuyente.isNotEmpty ? contribuyente[0].toString() : 'N/A';
      nombre = contribuyente.length > 1 ? contribuyente[1].toString() : 'N/A';
      direccion = contribuyente.length > 2
          ? contribuyente[2].toString()
          : 'N/A';
    } else if (contribuyente is Map) {
      nombre = contribuyente['nombre']?.toString() ?? 'N/A';
      direccion = contribuyente['direccion']?.toString() ?? 'N/A';
      cuenta = data['cuenta_numero']?.toString() ?? 'N/A';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: deuda != null && deuda > 0
              ? Colors.orange[200]!
              : Colors.green[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.electric_bolt_outlined,
                  size: 32,
                  color: Colors.purple[700],
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EERSSA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Empresa Eléctrica Regional',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Titular', nombre),
          _buildDivider(),
          _buildInfoRow('Cuenta N°', cuenta),
          _buildDivider(),
          _buildInfoRow('Dirección', direccion),
          if (deuda != null && deuda > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valor pendiente de pago',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${deuda.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sin valores pendientes de pago',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatriculacionCard(ServiceData service) {
    final data = service.data?['datos_servicio'];
    if (data == null) return _buildGenericCard(service);

    final vehiculo = data['vehiculo'] ?? {};
    final deuda = _extractAmount(service.data);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: deuda != null && deuda > 0
              ? Colors.orange[200]!
              : Colors.green[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  size: 32,
                  color: Colors.indigo[700],
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Matriculación Vehicular',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'SRI - Ecuador',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
            'Placa',
            service.data?['identificacion_detectada'] ?? 'N/A',
          ),
          _buildDivider(),
          _buildInfoRow('Marca', data['marca'] ?? 'N/A'),
          _buildDivider(),
          _buildInfoRow('Modelo', data['modelo'] ?? 'N/A'),
          _buildDivider(),
          _buildInfoRow('Año', data['anio'] ?? 'N/A'),
          _buildDivider(),
          _buildInfoRow('Color', data['color'] ?? 'N/A'),
          if (vehiculo['propietario'] != null) ...[
            _buildDivider(),
            _buildInfoRow('Propietario', vehiculo['propietario']),
          ],
          if (deuda != null && deuda > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Matriculación pendiente',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${deuda.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Matriculación al día',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenericCard(ServiceData service) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getServiceTitle(service.type),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          if (service.data != null)
            Text(
              service.data.toString(),
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
        ],
      ),
    );
  }

  Widget _buildClaroCard(ServiceData service) {
    // Extraer el texto del resultado
    final datosServicio = service.data?['datos_servicio'];
    final resultado = datosServicio is String
        ? datosServicio
        : datosServicio.toString();
    final numero = service.data?['identificacion_detectada'] ?? '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.red[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Planes Claro',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consulta de Saldo',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Número consultado
          if (numero.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: Colors.red[600], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Número: $numero',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Resultado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Estado del Plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  resultado,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: Color(0xFFE5E7EB), height: 1),
    );
  }

  Widget _buildPendingPaymentSection(PendingPayment payment) {
    final isOverdue = payment.status == 'overdue';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? Colors.red[200]! : Colors.orange[200]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOverdue ? Icons.error : Icons.warning_amber,
                color: isOverdue ? Colors.red[700] : Colors.orange[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isOverdue ? 'Pago vencido' : 'Pago pendiente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isOverdue ? Colors.red[900] : Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Monto a pagar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isOverdue ? Colors.red[700] : Colors.orange[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            payment.amount,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isOverdue ? Colors.red[700] : Colors.orange[700],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isOverdue ? Colors.red[700] : Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'Vencimiento: ${payment.dueDate}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? Colors.red[900] : Colors.orange[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta especial para errores y casos "sin registros"
  Widget _buildErrorCard(ServiceData service) {
    // Determinar si es un "no encontrado" o un error real
    final isNotFound =
        service.error != null &&
        (service.error!.toLowerCase().contains('no está registrada') ||
            service.error!.toLowerCase().contains('no se encontró') ||
            service.error!.toLowerCase().contains('no se pudo detectar') ||
            service.error!.toLowerCase().contains('not found'));

    final icon = isNotFound ? Icons.info_outline : Icons.error_outline;
    final color = isNotFound ? Colors.blue : Colors.red;
    final statusText = isNotFound ? 'Sin registros' : 'Error en consulta';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getServiceIcon(service.type),
                  size: 24,
                  color: color[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getServiceTitle(service.type),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color[200]!, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: color[700]),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (service.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color[200]!, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: color[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.error!,
                      style: TextStyle(fontSize: 12, color: color[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceCard(ServiceData service) {
    final isSuccess = service.success;
    final hasDebt =
        service.data != null &&
        _extractAmount(service.data) != null &&
        _extractAmount(service.data)! > 0;

    // Determinar si es un "no encontrado" para usar azul en vez de rojo
    final isNotFound =
        !isSuccess &&
        service.error != null &&
        (service.error!.toLowerCase().contains('no está registrada') ||
            service.error!.toLowerCase().contains('no se encontró') ||
            service.error!.toLowerCase().contains('not found'));

    final borderColor = !isSuccess
        ? (isNotFound ? Colors.blue[200]! : Colors.red[200]!)
        : (hasDebt ? Colors.orange[200]! : Colors.green[200]!);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: !isSuccess
                      ? (isNotFound ? Colors.blue[50] : Colors.red[50])
                      : (hasDebt ? Colors.orange[50] : Colors.green[50]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getServiceIcon(service.type),
                  size: 24,
                  color: !isSuccess
                      ? (isNotFound ? Colors.blue[700] : Colors.red[700])
                      : (hasDebt ? Colors.orange[700] : Colors.green[700]),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getServiceTitle(service.type),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildServiceStatus(service, hasDebt),
                  ],
                ),
              ),
            ],
          ),
          if (!isSuccess && service.error != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final isNotFound =
                    service.error!.toLowerCase().contains(
                      'no está registrada',
                    ) ||
                    service.error!.toLowerCase().contains('no se encontró') ||
                    service.error!.toLowerCase().contains('not found');

                final icon = isNotFound
                    ? Icons.info_outline
                    : Icons.error_outline;
                final color = isNotFound ? Colors.blue : Colors.red;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color[200]!, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 16, color: color[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          service.error!,
                          style: TextStyle(fontSize: 12, color: color[900]),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceStatus(ServiceData service, bool hasDebt) {
    if (!service.success) {
      // Determinar si es un "no encontrado" o un error real
      final isNotFound =
          service.error != null &&
          (service.error!.toLowerCase().contains('no está registrada') ||
              service.error!.toLowerCase().contains('no se encontró') ||
              service.error!.toLowerCase().contains('no se pudo detectar') ||
              service.error!.toLowerCase().contains('not found'));

      final icon = isNotFound ? Icons.info_outline : Icons.error;
      final color = isNotFound ? Colors.blue : Colors.red;
      final text = isNotFound ? 'Sin registros' : 'Error en consulta';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color[200]!, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color[700]),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color[700],
              ),
            ),
          ],
        ),
      );
    }

    if (hasDebt) {
      final amount = _extractAmount(service.data);
      return Text(
        'Deuda: \$${amount!.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.orange[700],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
          const SizedBox(width: 6),
          Text(
            'Al día',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PendingPayment payment) {
    final isOverdue = payment.status == 'overdue';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? Colors.red[200]! : Colors.orange[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red[50] : Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  payment.icon,
                  size: 24,
                  color: isOverdue ? Colors.red[700] : Colors.orange[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.amount,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isOverdue ? Colors.red[700] : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOverdue ? Colors.red[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOverdue ? Colors.red[200]! : Colors.orange[200]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOverdue ? Icons.error_outline : Icons.schedule,
                  size: 16,
                  color: isOverdue ? Colors.red[700] : Colors.orange[700],
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isOverdue
                        ? 'Vencido - ${payment.dueDate}'
                        : 'Vence: ${payment.dueDate}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOverdue ? Colors.red[700] : Colors.orange[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: widget.onNewVerification,
          style:
              ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                overlayColor: WidgetStateProperty.resolveWith<Color?>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.pressed)) {
                    return Colors.white.withValues(alpha: 0.1);
                  }
                  return null;
                }),
              ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 22),
              SizedBox(width: 12),
              Text(
                'Nueva consulta',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
