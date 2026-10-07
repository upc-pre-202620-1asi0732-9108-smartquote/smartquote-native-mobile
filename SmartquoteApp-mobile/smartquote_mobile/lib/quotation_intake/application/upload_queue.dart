import 'package:flutter/foundation.dart';

import '../../shared/domain/api_contract.dart';
import '../domain/quotation.dart';

class UploadEntry {
  UploadEntry(this.file);
  final UploadFile file;
  String stage = 'Pendiente';
  double? progress;
  String? quotationId;
  bool duplicate = false;
  Object? error;
}

class UploadQueue extends ChangeNotifier {
  UploadQueue(this.repository, this.requestId);
  final QuotationRepository repository;
  final String requestId;
  final entries = <UploadEntry>[];
  final _knownIds = <String>{};
  bool running = false, _disposed = false;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(
    List<UploadFile> files,
    JsonObject supplier, {
    Set<String> knownIds = const {},
  }) async {
    if (running || _disposed) return;
    entries.clear();
    _knownIds.clear();
    _knownIds.addAll(knownIds);
    entries.addAll(files.map(UploadEntry.new));
    running = true;
    changed();
    var cursor = 0;
    Future<void> worker() async {
      while (!_disposed && cursor < entries.length) {
        final entry = entries[cursor++];
        await _run(entry, supplier);
      }
    }

    try {
      await Future.wait([worker(), worker()]);
    } finally {
      running = false;
      changed();
    }
  }

  Future<void> retry(UploadEntry entry) async {
    if (running || _disposed) return;
    running = true;
    changed();
    try {
      await _run(entry, {});
    } finally {
      running = false;
      changed();
    }
  }

  Future<void> _run(UploadEntry entry, JsonObject supplier) async {
    entry.error = null;
    try {
      if (entry.file.validationError != null) {
        throw ApiFailure(entry.file.validationError!);
      }
      if (entry.file.bytes.isEmpty ||
          entry.file.bytes.length > 15 * 1024 * 1024 ||
          !entry.file.name.toLowerCase().endsWith('.pdf')) {
        throw const ApiFailure(
          'El documento debe ser un PDF de 1 byte a 15 MB.',
        );
      }
      Quotation quote;
      if (entry.quotationId == null) {
        entry.stage = 'Cargando';
        changed();
        quote = await repository.upload(
          requestId,
          entry.file,
          supplier,
          progress: (sent, total) {
            entry.progress = total > 0 ? sent / total : null;
            changed();
          },
        );
        entry.quotationId = quote.id;
        entry.duplicate = !_knownIds.add(quote.id);
      } else {
        quote = await repository.get(entry.quotationId!);
      }
      if (!_disposed && ['Uploaded', 'Rejected'].contains(quote.status)) {
        entry.stage = 'Procesando con IA';
        entry.progress = null;
        changed();
        quote = await repository.process(quote.id);
      }
      entry.stage = switch (quote.status) {
        'Verified' => 'Ya verificada',
        'RequiresVerification' => 'Lista para verificar',
        'Rejected' => 'Rechazada; consulta el motivo',
        'Processing' => 'Procesamiento en curso; actualiza después',
        _ => 'Pendiente de procesamiento',
      };
    } catch (e) {
      entry.error = e;
      entry.stage = 'No completada';
    } finally {
      changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
