import 'package:flutter/material.dart';
import 'package:proyecto_ocr/features/results/domain/entities/results_entities.dart';

class ResultsScreen extends StatelessWidget {
  final Function(DetailCategory) onViewDetail;
  final VoidCallback onNewVerification;

  const ResultsScreen({
    super.key,
    required this.onViewDetail,
    required this.onNewVerification,
  });

  @override
  Widget build(BuildContext context) {
    final userData = _getUserData();
    final categories = _getCategories();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(userData),
            Expanded(
              child: _buildCategoriesList(categories),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Map<String, String> _getUserData() {
    final now = DateTime.now();
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    
    return {
      'name': 'Jose Julio Gonzales Torres',
      'idNumber': '1106854793',
      'verificationDate': '${now.day.toString().padLeft(2, '0')} de ${months[now.month - 1]}, ${now.year}',
    };
  }

  List<DetailCategory> _getCategories() {
    return [
      DetailCategory(
        id: 'antecedentes',
        title: 'Antecedentes penales',
        icon: 'file',
        status: 'clear',
        recordCount: 0,
      ),
      DetailCategory(
        id: 'multas',
        title: 'Multas de tránsito',
        icon: 'alert',
        status: 'found',
        recordCount: 2,
        records: [
          Record(
            title: 'Exceso de velocidad',
            description: 'Carretera Interamericana, km 45',
            date: '15 de noviembre, 2024',
            status: 'Pendiente de pago',
            amount: '\$120.00',
          ),
          Record(
            title: 'Estacionamiento indebido',
            description: 'Zona azul, Centro',
            date: '03 de octubre, 2024',
            status: 'Pendiente de pago',
            amount: '\$45.00',
          ),
        ],
      ),
      DetailCategory(
        id: 'pensiones',
        title: 'Pensiones alimentarias',
        icon: 'dollar',
        status: 'clear',
        recordCount: 0,
      ),
    ];
  }

  Widget _buildHeader(Map<String, String> userData) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Verificación completada',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Paso 3/3',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                Icons.badge_outlined,
                'Cédula: ${userData['idNumber']}',
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
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF6B7280),
          ),
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

  Widget _buildCategoriesList(List<DetailCategory> categories) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Resultados de consulta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
        ),
        ...categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < categories.length - 1 ? 12 : 0,
            ),
            child: _buildCategoryCard(category),
          );
        }),
        const SizedBox(height: 24),
        _buildInfoBanner(),
      ],
    );
  }

  Widget _buildCategoryCard(DetailCategory category) {
    final hasRecords = category.status == 'found' && category.recordCount > 0;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onViewDetail(category),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasRecords 
                  ? Colors.orange[200]! 
                  : const Color(0xFFE5E7EB),
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getIconBackgroundColor(category.status),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(category.icon),
                  size: 24,
                  color: _getIconColor(category.status),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _getStatusBadge(category.status, category.recordCount),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getIconBackgroundColor(String status) {
    switch (status) {
      case 'clear':
        return Colors.green[50]!;
      case 'found':
        return Colors.orange[50]!;
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getIconColor(String status) {
    switch (status) {
      case 'clear':
        return Colors.green[700]!;
      case 'found':
        return Colors.orange[700]!;
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getIcon(String iconType) {
    switch (iconType) {
      case 'file':
        return Icons.description_outlined;
      case 'alert':
        return Icons.warning_amber_outlined;
      case 'dollar':
        return Icons.account_balance_wallet_outlined;
      case 'credit':
        return Icons.credit_card_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Widget _getStatusBadge(String status, int count) {
    if (status == 'clear') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.green[200]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 14,
              color: Colors.green[700],
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Sin registros',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'found') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.orange[200]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info,
              size: 14,
              color: Colors.orange[700],
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$count ${count == 1 ? "registro" : "registros"}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 14,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              'Pendiente',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline,
              size: 20,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Toque cada categoría para ver más detalles sobre los registros encontrados',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue[900],
                height: 1.4,
              ),
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
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onNewVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.refresh, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Nueva verificación',
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.share_outlined, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Compartir resultados',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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
}