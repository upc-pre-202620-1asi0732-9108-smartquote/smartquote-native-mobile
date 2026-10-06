import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/domain/api_contract.dart';
import '../domain/corporate_profile.dart';
import '../domain/purchase_order.dart';

Future<Uint8List> buildOrderPdf(
  PurchaseOrder order,
  CorporateProfile corporate,
) async {
  assertExportable(order);
  corporate.validate();
  final d = order.data;
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: 'Orden de compra ${d['orderNumber']}',
    author: corporate.name,
    subject: 'SmartQuote order ${order.id}',
    keywords:
        'order:${order.id};request:${d['purchaseRequestId']};simulation:${d['simulationRunId']};fingerprint:${d['inputFingerprint']}',
  );
  String amount(num? value) => value == null ? '-' : value.toStringAsFixed(2);
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            corporate.name,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('RUC: ${corporate.taxId}'),
          pw.Text(corporate.address),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(),
          pw.Text(
            'SmartQuote | Orden ${order.id} | Página ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (_) => [
        pw.Text(
          'ORDEN DE COMPRA ${d['orderNumber']}',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Proveedor: ${d['supplierBusinessName']}'),
        pw.Text('RUC: ${d['supplierTaxIdentifier']}'),
        pw.Text('Moneda original: ${d['currency']} | Estado: ${d['status']}'),
        pw.Text(
          'Aprobada: ${d['approvedAt']} | Responsable: ${d['approvedBy']}',
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: [
            '#',
            'Descripción',
            'Cantidad',
            'Unidad',
            'Precio unitario',
            'Subtotal',
          ],
          data: order.lines
              .map(
                (l) => [
                  l['lineNumber'],
                  l['description'],
                  l['quantity'],
                  l['unitOfMeasure'],
                  amount(l['unitPrice'] as num?),
                  amount(numberOf(l, 'quantity') * numberOf(l, 'unitPrice')),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'TOTAL: ${d['currency']} ${amount(d['total'] as num?)}',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Plazo: ${d['deliveryLeadTimeDays']} días'),
        pw.Text('Destino: ${d['deliveryDestination']}'),
        pw.Text('Condiciones: ${d['deliveryConditions']}'),
        pw.SizedBox(height: 16),
        pw.Text(
          'Trazabilidad de la versión aprobada',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Solicitud: ${d['purchaseRequestId']}'),
        pw.Text('Cotización: ${d['quotationId']}'),
        pw.Text('Simulación: ${d['simulationRunId']}'),
        pw.Text(
          'Huella: ${d['inputFingerprint']}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );
  return document.save();
}

Future<void> shareOrderPdf(
  PurchaseOrder order,
  CorporateProfile corporate,
) async {
  final bytes = await buildOrderPdf(order, corporate);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'SmartQuote-${textOf(order.data, 'orderNumber')}-${order.id}.pdf',
  );
}

class PdfOrderExporter implements OrderExporter {
  @override
  Future<void> export(PurchaseOrder order, CorporateProfile profile) =>
      shareOrderPdf(order, profile);
}
