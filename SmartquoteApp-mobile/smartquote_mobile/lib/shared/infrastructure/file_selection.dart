import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/api_contract.dart';

Future<List<UploadFile>> selectFiles({
  bool multiple = false,
  bool quotation = false,
}) async {
  final files = multiple
      ? await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: quotation
              ? ['pdf']
              : ['pdf', 'png', 'jpg', 'jpeg'],
        )
      : [
          await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: quotation
                ? ['pdf']
                : ['pdf', 'png', 'jpg', 'jpeg'],
          ),
        ].whereType<PlatformFile>().toList();
  if (files.length > 20) {
    throw const ApiFailure('Selecciona como máximo 20 documentos.');
  }
  final result = <UploadFile>[];
  for (final file in files) {
    try {
      final length = file.lengthSync() ?? await file.length();
      final maximum = (quotation ? 15 : 10) * 1024 * 1024;
      if (length == null || length == 0 || length > maximum) {
        if (quotation) {
          result.add(
            UploadFile(
              file.name,
              Uint8List(0),
              'application/pdf',
              validationError: '${file.name}: tamaño inválido; máximo 15 MB.',
            ),
          );
          continue;
        }
        throw ApiFailure(
          '${file.name}: tamaño inválido; máximo ${quotation ? 15 : 10} MB.',
        );
      }
      final extension = file.name.split('.').last.toLowerCase();
      final type = switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => throw ApiFailure('${file.name}: formato no permitido.'),
      };
      result.add(UploadFile(file.name, await file.readAsBytes(), type));
    } catch (error) {
      if (!quotation) rethrow;
      result.add(
        UploadFile(
          file.name,
          Uint8List(0),
          'application/pdf',
          validationError: error is ApiFailure
              ? error.message
              : '${file.name}: no se pudo leer el documento. Selecciónalo nuevamente.',
        ),
      );
    }
  }
  return result;
}
