import '../../shared/domain/api_contract.dart';

class Quotation {
  Quotation(this.data);
  final JsonObject data;
  String get id => textOf(data, 'quotationId');
  String get status => textOf(data, 'status');
  int get version => integerOf(data, 'version');
  List<JsonObject> get fields => objectsOf(data['fields']);
  List<JsonObject> get lines => objectsOf(data['lines']);
  bool get verified => status == 'Verified';
  bool get canConfirm =>
      status == 'RequiresVerification' &&
      lines.isNotEmpty &&
      fields
          .where((f) => f['isRequired'] == true)
          .every(
            (f) =>
                ['Resolved', 'Corrected'].contains(f['status']) &&
                textOf(f, 'currentValue').trim().isNotEmpty,
          ) &&
      textOf(data, 'supplierBusinessName').isNotEmpty &&
      textOf(data, 'supplierTaxIdentifier').isNotEmpty;
  num? get total =>
      lines.isEmpty ||
          lines.any((l) => l['quantity'] == null || l['unitPrice'] == null)
      ? null
      : lines.fold<double>(
          0,
          (sum, l) => sum + numberOf(l, 'quantity') * numberOf(l, 'unitPrice'),
        );
  static bool editable(String path) => RegExp(
    r'^(supplier\.(businessName|taxIdentifier)|validUntil|currency|deliveryLeadTimeDays|lines\[\d+\]\.(description|quantity|unitOfMeasure|unitPrice|specifications\[\d+\]\.value))$',
  ).hasMatch(path);
}

abstract interface class QuotationRepository {
  Future<List<Quotation>> list(String requestId);
  Future<Quotation> get(String id);
  Future<Quotation> upload(
    String requestId,
    UploadFile file,
    JsonObject supplier, {
    void Function(int, int)? progress,
  });
  Future<Quotation> process(String id);
  Future<void> correct(
    Quotation quotation,
    String fieldId,
    String value,
    String reason,
  );
  Future<void> addSpecification(
    Quotation quotation,
    String lineId,
    JsonObject specification,
  );
  Future<void> confirm(Quotation quotation, Map<String, String> mappings);
}
