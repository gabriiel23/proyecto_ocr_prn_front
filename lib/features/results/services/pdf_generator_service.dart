import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:proyecto_ocr/features/results/domain/entities/results_entities.dart';

class PdfGeneratorService {
  Future<Uint8List> generateReport({
    required Map<String, String> userData,
    required List<ServiceData> services,
    required List<PendingPayment> pendingPayments,
  }) async {
    // Determinar título del documento basado en el primer servicio
    String docTitle = 'Reporte de Cosulta';
    if (services.isNotEmpty) {
      docTitle = 'Reporte - ${_getServiceTitle(services.first.type)}';
    }

    final pdf = pw.Document(
      title: docTitle,
      author: 'Proyecto OCR',
      creator: 'Proyecto OCR',
      subject: 'Resultados de consulta de servicios públicos',
    );

    // Cargar fuente elegante (Open Sans)
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    // Cargar logo
    final logoImage = await imageFromAssetBundle('assets/logo-ocr-2.png');

    // Colores
    final primaryColor = PdfColor.fromInt(0xFF000000);
    final accentColor = PdfColor.fromInt(0xFF6B7280);
    final lightColor = PdfColor.fromInt(0xFFF3F4F6);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
        ),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(logoImage, primaryColor, accentColor),
            pw.SizedBox(height: 30),

            // Información del Usuario
            _buildUserInfo(userData, lightColor, primaryColor),
            pw.SizedBox(height: 30),

            // Servicios Consultados
            pw.Text(
              'Resultados de Inspección',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.Divider(color: lightColor, thickness: 1),
            pw.SizedBox(height: 10),

            ...services.map(
              (s) =>
                  _buildServiceSection(s, fontBold, lightColor, primaryColor),
            ),

            if (pendingPayments.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Text(
                'Valores Pendientes',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFDC2626), // Rojo
                ),
              ),
              pw.Divider(color: PdfColor.fromInt(0xFFFECACA), thickness: 1),
              pw.SizedBox(height: 10),
              ...pendingPayments.map((p) => _buildPaymentRow(p, fontBold)),
            ],

            // Footer marca de agua
            pw.Spacer(),
            pw.Divider(color: lightColor),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generado por Proyecto OCR',
                  style: pw.TextStyle(fontSize: 10, color: accentColor),
                ),
                pw.Text(
                  'Este documento es informativo.',
                  style: pw.TextStyle(fontSize: 10, color: accentColor),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
    pw.ImageProvider logo,
    PdfColor primary,
    PdfColor accent,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          children: [
            pw.Container(height: 50, width: 50, child: pw.Image(logo)),
            pw.SizedBox(width: 15),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'REPORTE DE CONSULTA',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                pw.Text(
                  'Servicios Públicos',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: accent,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'FECHA',
              style: pw.TextStyle(
                fontSize: 9,
                color: accent,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              DateTime.now().toString().substring(0, 16),
              style: pw.TextStyle(fontSize: 11, color: primary),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildUserInfo(
    Map<String, String> userData,
    PdfColor bg,
    PdfColor text,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CONTRIBUYENTE',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF6B7280),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  userData['name'] ?? 'Usuario',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
          if (userData['idNumber']?.isNotEmpty == true)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CÉDULA / RUC',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF6B7280),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    userData['idNumber']!,
                    style: pw.TextStyle(fontSize: 14, color: text),
                  ),
                ],
              ),
            ),
          if (userData['placa']?.isNotEmpty == true)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PLACA',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF6B7280),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    userData['placa']!.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: text,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildServiceSection(
    ServiceData service,
    pw.Font fontBold,
    PdfColor lightColor,
    PdfColor primaryColor,
  ) {
    if (!service.success) return pw.Container();

    final title = _getServiceTitle(service.type);
    final data = service.data;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF3F4F6),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF374151),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          if (data is Map) _buildServiceDataTable(data, service.type, fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildServiceDataTable(
    Map<dynamic, dynamic> data,
    String serviceType,
    pw.Font fontBold,
  ) {
    if (serviceType == 'luz_loja' || serviceType == 'eerssa') {
      return _buildLuzTable(data, fontBold);
    } else if (serviceType == 'sri_matriculacion') {
      return _buildMatriculacionTable(data, fontBold);
    } else if (serviceType == 'ocr_cedula') {
      return _buildOcrTable(data, fontBold);
    }

    // Fallback genérico mejorado
    return _buildGenericTable(data, fontBold);
  }

  pw.Widget _buildLuzTable(Map<dynamic, dynamic> data, pw.Font fontBold) {
    final rows = <pw.TableRow>[];
    final ds = data['datos_servicio'] ?? data;

    void addRow(String label, dynamic value) {
      if (value != null && value.toString().isNotEmpty) {
        rows.add(_buildRow(label, value.toString(), fontBold));
      }
    }

    if (ds is Map) {
      // Datos del Cliente
      if (ds['contribuyente'] != null) {
        final c = ds['contribuyente'];
        if (c is Map) {
          addRow('CLIENTE', c['nombre']);
          addRow('C.I./RUC', c['identificacion']);
          addRow('DIRECCIÓN', c['direccion']);
        } else if (c is List && c.length > 2) {
          addRow('CUENTA', c[0]); // A veces es cuenta
          addRow('CLIENTE', c[1]);
          addRow('DIRECCIÓN', c[2]);
        }
      }

      addRow('CUENTA', ds['cuenta_numero'] ?? ds['cuenta']);
      addRow('MEDIDOR', ds['medidor']);
      addRow('ESTADO', ds['estado']);

      // Fechas
      addRow('FECHA EMISIÓN', ds['fecha_emision']);
      addRow('VENCIMIENTO', ds['fecha_vencimiento'] ?? ds['fechaVencimiento']);

      // Consumos
      if (ds['consumo'] != null) {
        final cons = ds['consumo'];
        if (cons is Map) {
          addRow('CONSUMO (kWh)', cons['consumo_kwh'] ?? cons['valor']);
          addRow('LECTURA ACTUAL', cons['lectura_actual']);
          addRow('LECTURA ANTERIOR', cons['lectura_anterior']);
        }
      }

      // Deuda
      final deuda = ds['deuda'];
      if (deuda is Map) {
        if (deuda['tieneDeuda'] == true) {
          addRow('MESES MORA', deuda['mesesMora']);
        }
      }
    }

    if (rows.isEmpty) return _buildGenericTable(data, fontBold);

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  pw.Widget _buildMatriculacionTable(
    Map<dynamic, dynamic> data,
    pw.Font fontBold,
  ) {
    final rows = <pw.TableRow>[];
    final ds = data['datos_servicio'] ?? data;

    void addRow(String label, dynamic value) {
      if (value != null && value.toString().isNotEmpty) {
        rows.add(_buildRow(label, value.toString(), fontBold));
      }
    }

    if (ds is Map) {
      addRow('PLACA', data['placa'] ?? data['identificacion_detectada']);

      addRow('MARCA', ds['marca']);
      addRow('MODELO', ds['modelo']);
      addRow('AÑO', ds['anio']);
      addRow('COLOR', ds['color']);
      addRow('CLASE', ds['clase']);
      addRow('SERVICIO', ds['servicio']);

      addRow('MOTOR', ds['motor']);
      addRow('CHASIS', ds['chasis']);

      final vehiculo = ds['vehiculo'];
      if (vehiculo is Map) {
        addRow('PROPIETARIO', vehiculo['propietario']);
      }

      final matricula = ds['matricula'];
      if (matricula is Map) {
        addRow('FECHA MATRÍCULA', matricula['fecha_matricula']);
        addRow('CADUCIDAD', matricula['fecha_caducidad']);
      }
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  pw.Widget _buildOcrTable(Map<dynamic, dynamic> data, pw.Font fontBold) {
    final rows = <pw.TableRow>[];

    void addRow(String label, dynamic value) {
      if (value != null && value.toString().isNotEmpty) {
        rows.add(_buildRow(label, value.toString(), fontBold));
      }
    }

    // Encabezado fijo
    addRow('DOCUMENTO', 'CÉDULA DE IDENTIDAD');
    addRow('NÚMERO IDENTIFICACIÓN', data['identificacion_detectada']);

    if (data['texto_detectado'] != null) {
      final texto = data['texto_detectado'].toString();

      // --- NUEVO PARSER ROBUSTO CON REGEX ---
      // Normalizamos el texto: mayúsculas y eliminamos caracteres extraños al inicio de líneas
      String cleanRaw = texto.toUpperCase();

      // Definimos patrones regex para capturar contenido entre palabras clave
      // (?<=KEYWORD) -> Lookbehind: busca después de KEYWORD
      // ([\s\S]*?)   -> Captura cualquier caracter (incluyendo saltos de línea) de forma "lazy" (lo mínimo posible)
      // (?=NEXT_KEY) -> Lookahead: hasta encontrar NEXT_KEY

      String? extractField(String startKey, List<String> endKeys) {
        try {
          // Construimos el patrón de fin (ej: NOMBRES|CONDICIÓN|NACIONALIDAD)
          final endPattern = endKeys.join('|');

          // Regex: Busca la clave de inicio, permite : o espacios, y captura hasta encontrar alguna clave de fin
          final regExp = RegExp(
            '$startKey\\s*[:.]?\\s*([\\s\\S]*?)(?=$endPattern|\$)',
            multiLine: true,
            dotAll: true,
          );

          final match = regExp.firstMatch(cleanRaw);
          if (match != null && match.group(1) != null) {
            final val = match
                .group(1)!
                .replaceAll(
                  RegExp(r'\n+'),
                  ' ',
                ) // Reemplazar saltos de línea internos por espacios
                .replaceAll(RegExp(r'\s+'), ' ') // Eliminar espacios múltiples
                .trim();
            // Evitar retornar vacío o solo signos
            return (val.length > 1 && val != ':') ? val : null;
          }
        } catch (e) {
          // Fallo silencioso en regex
        }
        return null;
      }

      Map<String, String> parsedFields = {};
      parsedFields['APELLIDOS'] =
          extractField('APELLIDOS', ['NOMBRES', 'CONDICIÓN', 'NACIONALIDAD']) ??
          '';
      parsedFields['NOMBRES'] =
          extractField('NOMBRES', ['NACIONALIDAD', 'FECHA', 'LUGAR']) ?? '';
      parsedFields['NACIONALIDAD'] =
          extractField('NACIONALIDAD', ['FECHA', 'SEXO']) ?? '';
      parsedFields['FECHA NACIMIENTO'] =
          extractField('FECHA DE NACIMIENTO', ['LUGAR', 'SEXO']) ?? '';
      parsedFields['LUGAR NACIMIENTO'] =
          extractField('LUGAR DE NACIMIENTO', ['SEXO', 'ESTADO', 'FIRMA']) ??
          '';
      parsedFields['SEXO'] =
          extractField('SEXO', ['NO.', 'ESTADO', 'FECHA']) ?? '';
      parsedFields['ESTADO CIVIL'] =
          extractField('ESTADO CIVIL', ['APELLIDOS', 'LUGAR']) ?? '';

      // Limpiar campos vacíos
      parsedFields.removeWhere((key, value) => value.isEmpty);

      // Si logramos parsear algo importante (Apellidos o Nombres), usamos este método
      if (parsedFields.containsKey('APELLIDOS') ||
          parsedFields.containsKey('NOMBRES')) {
        // Mostrar en orden específico
        final displayOrder = [
          'APELLIDOS',
          'NOMBRES',
          'NACIONALIDAD',
          'FECHA NACIMIENTO',
          'LUGAR NACIMIENTO',
          'SEXO',
          'ESTADO CIVIL',
        ];

        for (var key in displayOrder) {
          if (parsedFields.containsKey(key)) {
            addRow(key, parsedFields[key].toString());
          }
        }
      } else {
        // Fallback: mostrar el texto crudo pero limpio
        final lines = texto
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        final cleanText = lines.join('\n');
        final extracto = cleanText.length > 500
            ? '${cleanText.substring(0, 500)}...'
            : cleanText;

        addRow('TEXTO DETECTADO (RAW)', extracto);
      }
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  pw.Widget _buildGenericTable(Map<dynamic, dynamic> data, pw.Font fontBold) {
    final rows = <pw.TableRow>[];
    Map<String, dynamic> flattened = {};

    void flatten(dynamic curr, [String prefix = '']) {
      if (curr is Map) {
        curr.forEach((k, v) {
          flatten(v, prefix.isEmpty ? k.toString() : '\$prefix > \$k');
        });
      } else if (curr is List) {
        for (var i = 0; i < curr.length && i < 3; i++) {
          flatten(curr[i], '\$prefix [\$i]');
        }
      } else if (curr != null && curr.toString().isNotEmpty) {
        if (curr.toString().length < 500) {
          flattened[prefix] = curr.toString();
        }
      }
    }

    flatten(data);

    flattened.forEach((key, value) {
      if (key.contains('base64') ||
          key == 'success' ||
          key == 'mensaje' ||
          key == 'error') {
        return;
      }
      rows.add(_buildRow(key.toUpperCase(), value, fontBold));
    });

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  pw.TableRow _buildRow(String label, String value, pw.Font fontBold) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromInt(0xFF6B7280),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromInt(0xFF111827),
              font: fontBold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPaymentRow(PendingPayment payment, pw.Font fontBold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFFEE2E2)),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColor.fromInt(0xFFFEF2F2),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(payment.title, style: pw.TextStyle(fontSize: 12)),
          pw.Text(
            payment.amount,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  String _getServiceTitle(String type) {
    switch (type) {
      case 'luz_loja':
        return 'Planilla de Luz';
      case 'sri_matriculacion':
        return 'Matriculación Vehicular';
      case 'ocr_cedula':
        return 'Lectura de Cédula';
      default:
        return type;
    }
  }
}
