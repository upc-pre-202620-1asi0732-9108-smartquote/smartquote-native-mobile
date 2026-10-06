import '../../shared/domain/api_contract.dart';
import '../domain/quotation.dart';

class HttpQuotationRepository implements QuotationRepository {
  HttpQuotationRepository(this.api);
  final ApiGateway api;
  @override
  Future<List<Quotation>> list(String requestId) async =>
      objectsOf(await api.request('/purchase-requests/$requestId/quotations'))
          .map(Quotation.new)
          .toList();
  @override
  Future<Quotation> get(String id) async =>
      Quotation(objectOf(await api.request('/quotations/$id')));
  @override
  Future<Quotation> upload(
    String requestId,
    UploadFile file,
    JsonObject supplier, {
    void Function(int, int)? progress,
  }) async => Quotation(
    objectOf(
      await api.request(
        '/purchase-requests/$requestId/quotations',
        method: 'POST',
        body: MultipartPayload(supplier, {
          'file': [file],
        }),
        onSendProgress: progress,
      ),
    ),
  );
  @override
  Future<Quotation> process(String id) async => Quotation(
    objectOf(
      await api.request(
        '/quotations/$id/process',
        method: 'POST',
        timeout: const Duration(minutes: 3),
      ),
    ),
  );
  @override
  Future<void> correct(
    Quotation quotation,
    String fieldId,
    String value,
    String reason,
  ) async {
    await api.request(
      '/quotations/${quotation.id}/fields/$fieldId',
      method: 'PUT',
      body: {
        'value': value,
        'reason': reason,
        'expectedVersion': quotation.version,
      },
    );
  }

  @override
  Future<void> addSpecification(
    Quotation quotation,
    String lineId,
    JsonObject specification,
  ) async {
    await api.request(
      '/quotations/${quotation.id}/lines/$lineId/specifications',
      method: 'POST',
      body: {...specification, 'expectedVersion': quotation.version},
    );
  }

  @override
  Future<void> confirm(
    Quotation quotation,
    Map<String, String> mappings,
  ) async {
    if (quotation.lines.any(
      (line) => mappings[textOf(line, 'lineId')]?.isNotEmpty != true,
    )) {
      throw const ApiFailure('Asigna cada línea a un ítem de la solicitud.');
    }
    await api.request(
      '/quotations/${quotation.id}/confirm',
      method: 'POST',
      body: {
        'expectedVersion': quotation.version,
        'lineMappings': mappings.entries
            .map((e) => {'lineId': e.key, 'requestedItemId': e.value})
            .toList(),
      },
    );
  }
}
