import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:proyecto_ocr/features/home/presentation/pages/home_page.dart';
import 'package:proyecto_ocr/features/photo/presentation/pages/photo_page.dart';
import 'package:proyecto_ocr/features/processing/presentation/pages/processing_page.dart';
import 'package:proyecto_ocr/features/results/presentation/pages/results_page.dart';
import 'package:proyecto_ocr/features/selection_service/selection.service_page.dart';
import 'package:proyecto_ocr/features/claro_input/presentation/pages/claro_input_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,

  errorBuilder: (context, state) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error de navegación',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Ruta no encontrada',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  },

  routes: [
    // HOME: Pantalla inicial
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) {
        return HomeScreen(
          onStart: () {
            // Ir a selección de servicio
            context.push('/selection-service');
          },
        );
      },
    ),

    // SELECTION_SERVICE: Selección de servicio a consultar
    GoRoute(
      path: '/selection-service',
      name: 'selection-service',
      builder: (context, state) {
        return SelectionServiceScreen(
          onServiceSelected: (ServiceType service) {
            // Si es Claro, ir directamente a input manual (sin cámara)
            if (service == ServiceType.claroPlanes) {
              context.push('/claro-input');
            } else {
              // Para otros servicios, ir a captura de foto
              context.push('/photo', extra: service);
            }
          },
          onBack: () => context.pop(),
        );
      },
    ),

    // CLARO_INPUT: Input manual de número de celular (sin cámara)
    GoRoute(
      path: '/claro-input',
      name: 'claro-input',
      builder: (context, state) {
        return const ClaroInputPage();
      },
    ),

    // PHOTO: Captura de cédula o placa
    GoRoute(
      path: '/photo',
      name: 'photo',
      builder: (context, state) {
        // Obtener el servicio seleccionado
        final service = state.extra as ServiceType?;

        if (service == null) {
          // Si no hay servicio, redirigir a selección
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/selection-service');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return PhotoScreen(
          service: service,
          onCapture: (String captureResult) {
            String image = captureResult;
            String? imageBack;

            // Intentar detectar si es JSON (doble captura)
            if (captureResult.startsWith('{')) {
              try {
                final decoded = jsonDecode(captureResult);
                image = decoded['front'];
                imageBack = decoded['back'];
              } catch (e) {
                // No es json, es base64 normal
              }
            }

            // Ir a procesamiento pasando la imagen y el servicio
            context.push(
              '/processing',
              extra: {
                'image': image,
                'imageBack': imageBack,
                'service': service,
              },
            );
          },
          onBack: () {
            context.pop();
          },
        );
      },
    ),

    // PROCESSING: Consulta a servicios
    GoRoute(
      path: '/processing',
      name: 'processing',
      builder: (context, state) {
        // Validar que el extra existe y tiene la estructura correcta
        final data = state.extra as Map<String, dynamic>?;

        if (data == null || data['image'] == null || data['service'] == null) {
          // Si no hay datos, redirigir a selección de servicio
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/selection-service');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ProcessingScreen(
          base64Image: data['image'] as String,
          base64ImageBack: data['imageBack'] as String?,
          service: data['service'] as ServiceType,
          onComplete: (List results) {
            // Ir a resultados pasando los datos procesados
            context.go('/results', extra: results);
          },
          onError: () {
            // En caso de error, volver a photo
            context.go('/photo');
          },
        );
      },
    ),

    // RESULTS: Mostrar resultados
    GoRoute(
      path: '/results',
      name: 'results',
      builder: (context, state) {
        // Validar que los resultados existen
        final results = state.extra as List?;

        if (results == null || results.isEmpty) {
          // Si no hay resultados, volver al inicio
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ResultsScreen(
          results: results,
          onNewVerification: () {
            // Volver al inicio y limpiar todo el stack
            context.go('/');
          },
        );
      },
    ),
  ],
);
