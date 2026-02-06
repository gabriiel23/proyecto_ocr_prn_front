import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

import 'package:proyecto_ocr/features/selection_service/selection.service_page.dart';

class PhotoScreen extends StatefulWidget {
  final void Function(String base64Image) onCapture;
  final VoidCallback onBack;
  final ServiceType service;

  const PhotoScreen({
    super.key,
    required this.onCapture,
    required this.onBack,
    required this.service,
  });

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen>
    with SingleTickerProviderStateMixin {
  bool _captured = false;
  bool _isCapturing = false;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _pulseController;
  // Variable eliminada: XFile? _lastPhoto;

  // Variables para flujo de doble captura (OCR)
  String? _frontImageBase64;
  int _captureStep = 1; // 1: Frontal, 2: Reverso

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isDualCapture => widget.service == ServiceType.ocr;

  Future<void> _handleCapture() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 95,
      );

      if (photo != null) {
        setState(() {
          _captured = true;
          // _lastPhoto = photo;
        });

        // Esperar animación
        await Future.delayed(const Duration(milliseconds: 600));

        // Convertir imagen a base64
        final bytes = await File(photo.path).readAsBytes();
        final base64Image = base64Encode(bytes);

        // LÓGICA DE FLUJO
        if (_isDualCapture && _captureStep == 1) {
          // Si es el primer paso de OCR, guardar y pedir siguiente
          setState(() {
            _frontImageBase64 = base64Image;
            _captureStep = 2; // Avanzar al paso 2
            _captured = false;
            _isCapturing = false;
            // _lastPhoto = null;
          });
        } else {
          // Si es captura única o el segundo paso de OCR, finalizar

          if (_isDualCapture) {
            // Enviar AMBAS imágenes codificadas en un JSON especial o separador
            // Nota: Modificaremos la firma del callback usando un string JSON
            // para no romper la compatibilidad con otras pantallas,
            // o simplemente pasamos el backImage y el front ya lo tenemos.
            // MEJOR: Pasamos un objeto JSON stringificado si es doble.

            final payload = jsonEncode({
              'front': _frontImageBase64,
              'back': base64Image,
            });

            widget.onCapture(payload);
          } else {
            // Flujo normal (una sola imagen)
            widget.onCapture(base64Image);
          }

          // Resetear estado para futura captura (si el usuario vuelve)
          if (mounted) {
            setState(() {
              _captured = false;
              _isCapturing = false;
              // Si vuelve, resetear también el paso de OCR
              if (_isDualCapture) {
                _captureStep = 1;
                _frontImageBase64 = null;
              }
            });
          }
        }
      } else {
        setState(() {
          _isCapturing = false;
        });
      }
    } catch (e) {
      debugPrint('Error al capturar foto: $e');
      setState(() {
        _isCapturing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo acceder a la cámara'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            // Expanded contiene todo el contenido scrolleable
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [_buildPhotoView(), _buildCaptureButton()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String stepText = 'Paso 1/3';
    if (_isDualCapture) {
      // En OCR recalculamos:
      // Paso 1 (F) -> 1/4 ? No, mantengamos simple.
      // Paso 1: Frente (1/3)
      // Paso 2: Reverso (2/3)
      // Procesando (3/3)
      stepText = _captureStep == 1 ? 'Paso 1/3' : 'Paso 2/3';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_isDualCapture && _captureStep == 2) {
                  // Si vuelve atrás desde el paso 2, regresar al paso 1
                  setState(() {
                    _captureStep = 1;
                    _frontImageBase64 = null;
                  });
                } else {
                  widget.onBack();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isDualCapture
                  ? (_captureStep == 1 ? 'Capturar FRENTE' : 'Capturar REVERSO')
                  : 'Capturar cédula',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              stepText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoView() {
    return Container(
      // Altura fija basada en el viewport
      height: MediaQuery.of(context).size.height * 0.65,
      color: const Color(0xFF1F2937),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1F2937), Color(0xFF111827)],
              ),
            ),
          ),
          if (_captured)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 0.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Container(color: Colors.white.withValues(alpha: value));
              },
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: _buildInstructionsCard()),

                  const SizedBox(height: 40),

                  Flexible(child: _buildCaptureFrame()),

                  const SizedBox(height: 12),

                  Text(
                    _isDualCapture
                        ? (_captureStep == 1
                              ? 'Alinee el FRENTE de la cédula'
                              : 'Alinee el REVERSO de la cédula')
                        : 'Asegúrese de que todos los datos sean legibles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInstruction(
            Icons.wb_sunny_outlined,
            'Buena iluminación',
            'Evite sombras',
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),
          _buildInstruction(
            Icons.flash_off_outlined,
            'Sin reflejos',
            'No use flash',
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),
          _buildInstruction(
            Icons.crop_free,
            'Documento completo',
            'Dentro del marco',
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF374151)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureFrame() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
        maxHeight: 200,
      ),
      child: AspectRatio(
        aspectRatio: 1.6,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseValue = _pulseController.value;
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: _captured
                          ? Colors.green
                          : Colors.white.withValues(
                              alpha: 0.3 + (pulseValue * 0.2),
                            ),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _captured
                        ? Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green[400],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 40,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isDualCapture
                                    ? (_captureStep == 1
                                          ? 'Alinee FRENTE'
                                          : 'Alinee REVERSO')
                                    : 'Alinee la cédula',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (!_captured) ...[
                  _buildCornerGuide(Alignment.topLeft, true, true),
                  _buildCornerGuide(Alignment.topRight, true, false),
                  _buildCornerGuide(Alignment.bottomLeft, false, true),
                  _buildCornerGuide(Alignment.bottomRight, false, false),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCornerGuide(Alignment alignment, bool top, bool left) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(4),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(8) : Radius.zero,
            topRight: top && !left ? const Radius.circular(8) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(8) : Radius.zero,
            bottomRight: !top && !left ? const Radius.circular(8) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_captured || _isCapturing) ? null : _handleCapture,
                style:
                    ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _captured
                          ? Colors.green[600]
                          : Colors.grey[300],
                      disabledForegroundColor: _captured
                          ? Colors.white
                          : Colors.grey[500],
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
                child: _isCapturing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _captured ? Icons.check_circle : Icons.photo_camera,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _captured ? 'Foto capturada' : 'Tomar fotografía',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 10),
            Text(
              _captured
                  ? 'Procesando imagen...'
                  : 'Presione para abrir la cámara',
              style: TextStyle(
                fontSize: 14,
                color: const Color.fromARGB(255, 0, 0, 0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
