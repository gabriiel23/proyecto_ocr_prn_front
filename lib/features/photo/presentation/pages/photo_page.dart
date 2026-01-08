import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoScreen extends StatefulWidget {
  final VoidCallback onCapture;
  final VoidCallback onBack;

  const PhotoScreen({
    super.key,
    required this.onCapture,
    required this.onBack,
  });

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> with SingleTickerProviderStateMixin {
  bool _captured = false;
  bool _isCapturing = false;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _pulseController;

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
        });

        // Feedback visual de éxito
        await Future.delayed(const Duration(milliseconds: 600));
        widget.onCapture();
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
      
      // Mostrar feedback de error al usuario
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
            // Header con mejor affordance
            _buildHeader(),

            // Camera/Photo View
            Expanded(
              child: _buildPhotoView(),
            ),

            // Capture Button con feedback mejorado
            _buildCaptureButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Botón de retroceso con área táctil adecuada
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Título con jerarquía clara
          const Expanded(
            child: Text(
              'Capturar cédula',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Indicador de paso (visibilidad del sistema)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Paso 1/3',
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
      color: const Color(0xFF1F2937),
      child: Stack(
        children: [
          // Background con patrón sutil
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1F2937),
                  const Color(0xFF111827),
                ],
              ),
            ),
          ),

          // Flash blanco al capturar (feedback visual)
          if (_captured)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 0.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Container(
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(value),
                );
              },
            ),

          // Guía de cámara principal
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Card de instrucciones arriba
                  _buildInstructionsCard(),
                  
                  const SizedBox(height: 32),
                  
                  // Frame de captura
                  _buildCaptureFrame(),
                  
                  const SizedBox(height: 24),
                  
                  // Texto de ayuda debajo del frame
                  Text(
                    'Asegúrese de que todos los datos sean legibles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
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
      padding: const EdgeInsets.all(16),
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
        children: [
          _buildInstruction(
            Icons.wb_sunny_outlined,
            'Buena iluminación',
            'Evite sombras sobre el documento',
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 12),
          _buildInstruction(
            Icons.flash_off_outlined,
            'Sin reflejos',
            'No use flash si hay superficies brillantes',
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 12),
          _buildInstruction(
            Icons.crop_free,
            'Documento completo',
            'Capture toda la cédula dentro del marco',
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
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureFrame() {
    return AspectRatio(
      aspectRatio: 1.6,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue = _pulseController.value;
          return Stack(
            children: [
              // Frame principal con animación de pulso sutil
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05), 
                  border: Border.all(
                    color: _captured 
                        ? Colors.green 
                        : Colors.white.withValues(alpha: 0.3 + (pulseValue * 0.2)),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _captured
                      ? Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green[400],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card,
                              size: 56,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Alinee la cédula aquí',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Corner guides mejorados
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
            top: top ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            bottom: !top ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            left: left ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            right: !left ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
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
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón principal
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_captured || _isCapturing) ? null : _handleCapture,
              style: ElevatedButton.styleFrom(
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
                overlayColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.pressed)) {
                      return Colors.white.withValues(alpha: 0.1);
                    }
                    return null;
                  },
                ),
              ),
              child: _isCapturing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _captured 
                              ? Icons.check_circle 
                              : Icons.photo_camera,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _captured ? 'Foto capturada' : 'Tomar fotografía',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          // Texto de ayuda
          const SizedBox(height: 12),
          Text(
            _captured 
                ? 'Procesando imagen...' 
                : 'Presione para abrir la cámara',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}