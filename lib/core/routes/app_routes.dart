import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proyecto_ocr/features/home/presentation/pages/home_page.dart';
import 'package:proyecto_ocr/features/photo/presentation/pages/photo_page.dart';
import 'package:proyecto_ocr/features/processing/presentation/pages/processing_page.dart';
import 'package:proyecto_ocr/features/results/presentation/pages/results_page.dart';
import 'package:proyecto_ocr/features/results/domain/entities/results_entities.dart';
import 'package:proyecto_ocr/features/detail/presentation/pages/detail_page.dart';


// Mock data for DetailCategory to resolve the error
final mockDetailCategory = DetailCategory(
  id: 'antecedentes',
  title: 'Antecedentes penales',
  icon: 'file',
  status: 'clear',
  recordCount: 0,
);

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return HomeScreen(onStart: () {
          context.go('/photo');
        });
      },
    ),
    GoRoute(
      path: '/photo',
      builder: (BuildContext context, GoRouterState state) {
        return PhotoScreen(
          onCapture: () {
            context.go('/processing');
          },
          onBack: () {
            context.go('/');
          },
        );
      },
    ),
    GoRoute(
      path: '/processing',
      builder: (BuildContext context, GoRouterState state) {
        // This is a loading screen, so we'll simulate a delay and then navigate to results
        Future.delayed(const Duration(seconds: 3), () {
          // ignore: use_build_context_synchronously
          context.go('/results');
        });
        return const ProcessingScreen();
      },
    ),
    GoRoute(
      path: '/results',
      builder: (BuildContext context, GoRouterState state) {
        return ResultsScreen(
          onViewDetail: (category) {
            context.go('/detail', extra: category);
          },
          onNewVerification: () {
            context.go('/');
          },
        );
      },
    ),
    GoRoute(
      path: '/detail',
      builder: (BuildContext context, GoRouterState state) {
        // In a real app, you would pass the category as an argument
        // For now, we'll use a mock or the extra from the state
        final DetailCategory category = (state.extra as DetailCategory?) ?? mockDetailCategory;
        return DetailScreen(
          category: category,
          onBack: () {
            context.go('/results');
          },
        );
      },
    ),
  ],
);