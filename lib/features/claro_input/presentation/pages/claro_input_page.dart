import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:proyecto_ocr/core/config/backend_config.dart';
import 'package:proyecto_ocr/core/widgets/branding_footer.dart';

class ClaroInputPage extends StatefulWidget {
  const ClaroInputPage({super.key});

  @override
  State<ClaroInputPage> createState() => _ClaroInputPageState();
}

class _ClaroInputPageState extends State<ClaroInputPage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _currentStep = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String phone) {
    // Validar formato ecuatoriano: 09XXXXXXXX (10 dígitos, inicia con 09)
    return RegExp(r'^09\d{8}$').hasMatch(phone);
  }

  Future<void> _consultarPlan() async {
    final phone = _phoneController.text.trim();

    // Validar número
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa tu número de celular';
      });
      return;
    }

    if (!_isValidPhone(phone)) {
      setState(() {
        _errorMessage =
            'Número inválido. Debe ser 09 + 8 dígitos (ej: 0987654321)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentStep = 1;
    });

    try {
      // Simular progreso visual
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isLoading) setState(() => _currentStep = 2);
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isLoading) setState(() => _currentStep = 3);
      });

      debugPrint('📡 Consultando Claro para: $phone');

      final response = await http.post(
        Uri.parse('${BackendConfig.baseUrl}/cloud/consultar-claro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'numero': phone}),
      );
      if (!mounted) return;

      debugPrint('✅ Respuesta recibida: ${response.statusCode}');
      debugPrint('📦 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📊 Data parseada: $data');

        final resultado = data['resultado'];
        debugPrint('🎯 Resultado: $resultado');

        // Navegar a Results
        context.go(
          '/results',
          extra: [
            {
              'serviceType': 'claro_planes',
              'success': true,
              'data': {
                'identificacion_detectada': phone,
                'tipo_detectado': 'numero',
                'datos_servicio': resultado,
                'texto_detectado': '',
              },
            },
          ],
        );
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage =
              'El número ingresado no existe o no tiene servicios activos en Claro.';
          _isLoading = false;
        });
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
        setState(() {
          _errorMessage = 'No se pudo consultar el plan. Intenta de nuevo.';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('💥 Error capturado: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Error de conexión. Verifica tu internet.';
        _isLoading = false;
      });
    }
  }

  Widget _buildStepsLoading() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          _buildStep(1, 'Conectando con Claro...', _currentStep >= 1),
          _buildStep(2, 'Verificando número...', _currentStep >= 2),
          _buildStep(3, 'Consultando valores...', _currentStep >= 3),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isActive ? Colors.red : Colors.grey[300],
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isActive ? Colors.black87 : Colors.grey[400],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Consulta Claro',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone_android_rounded,
                size: 48,
                color: Colors.red[600],
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'Ingresa tu número celular',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Consultaremos el estado de tu plan y saldo',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            if (_isLoading)
              _buildStepsLoading()
            else ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(fontSize: 20, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: '09XXXXXXXX',
                    counterText: "",
                    prefixIcon: const Icon(Icons.dialpad, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _consultarPlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Consultar Plan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const BrandingFooter(),
          ],
        ),
      ),
    );
  }
}
