import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/quotation_intake/application/upload_queue.dart';
import 'package:smartquote_mobile/quotation_intake/domain/quotation.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';

import 'support/fixtures.dart';

class QueueRepository implements QuotationRepository {
  int active = 0, maximumActive = 0, uploads = 0;
  final ids = <String>{};
  @override
  Future<Quotation> upload(
    String requestId,
    UploadFile file,
    JsonObject supplier, {
    void Function(int, int)? progress,
  }) async {
    uploads++;
    active++;
    if (active > maximumActive) maximumActive = active;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active--;
    progress?.call(10, 10);
    if (file.name == 'damaged.pdf') {
      throw const ApiFailure('PDF dañado', status: 422);
    }
    ids.add(file.name);
    return Quotation(quoteFixture(id: file.name, status: 'Uploaded'));
  }

  @override
  Future<Quotation> process(String id) async {
    active++;
    if (active > maximumActive) maximumActive = active;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active--;
    return Quotation(quoteFixture(id: id, status: 'RequiresVerification'));
  }

  @override
  Future<Quotation> get(String id) async =>
      Quotation(quoteFixture(id: id, status: 'RequiresVerification'));
  @override
  Future<List<Quotation>> list(String requestId) async => [];
  @override
  Future<void> correct(
    Quotation quotation,
    String fieldId,
    String value,
    String reason,
  ) async {}
  @override
  Future<void> addSpecification(
    Quotation quotation,
    String lineId,
    JsonObject specification,
  ) async {}
  @override
  Future<void> confirm(
    Quotation quotation,
    Map<String, String> mappings,
  ) async {}
}

void main() {
  // US04 E3: Existing quotations are marked as duplicates without adding fabricated IDs.
  test('US04 E3 — Existing quotations are marked as duplicates without adding fabricated IDs', () async {
    final repository = QueueRepository();
    final queue = UploadQueue(repository, requestId);
    addTearDown(queue.dispose);
    await queue.start(
      [fileFixture('cotizacion.pdf')],
      {},
      knownIds: {'cotizacion.pdf'},
    );
    expect(queue.entries.single.duplicate, true);
    expect(queue.entries.single.quotationId, 'cotizacion.pdf');
  });
  // US10 E1 E2: Queue limits concurrency to two and isolates invalid documents.
  test('US10 E1 E2 — Queue limits concurrency to two and isolates invalid documents', () async {
    final repository = QueueRepository();
    final queue = UploadQueue(repository, requestId);
    addTearDown(queue.dispose);
    await queue.start([
      fileFixture('one.pdf'),
      fileFixture('damaged.pdf'),
      fileFixture('three.pdf'),
      UploadFile(
        'oversize.pdf',
        Uint8List(0),
        'application/pdf',
        validationError: 'Más de 15 MB',
      ),
    ], {});
    expect(repository.maximumActive, lessThanOrEqualTo(2));
    expect(queue.entries.where((e) => e.error == null).length, 2);
    expect(queue.entries.where((e) => e.error != null).length, 2);
    expect(repository.uploads, 3);
    expect(queue.running, false);
  });
  // US10 E3: Retry an existing document does not upload or process it again.
  test(
    'US10 E3 — Retry an existing document does not upload or process it again',
    () async {
      final repository = QueueRepository();
      final queue = UploadQueue(repository, requestId);
      addTearDown(queue.dispose);
      await queue.start([fileFixture()], {});
      final count = repository.uploads;
      await queue.retry(queue.entries.first);
      expect(repository.uploads, count);
      expect(queue.entries.first.stage, 'Lista para verificar');
    },
  );
}
