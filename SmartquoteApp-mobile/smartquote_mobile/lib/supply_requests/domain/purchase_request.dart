import '../../shared/domain/api_contract.dart';

class PurchaseRequest {
  PurchaseRequest(this.data);
  final JsonObject data;
  String get id => textOf(data, 'requestId');
  String get status => textOf(data, 'status');
  int get version => integerOf(data, 'version');
  List<JsonObject> get items => objectsOf(data['items']);
  List<JsonObject> get attachments => objectsOf(data['attachments']);
  List<JsonObject> get requirements =>
      items.expand((item) => objectsOf(item['requirements'])).toList();
}

class RequestPage {
  RequestPage(JsonObject data)
    : items = objectsOf(data['items']).map(PurchaseRequest.new).toList(),
      page = integerOf(data, 'page'),
      totalPages = integerOf(data, 'totalPages'),
      totalItems = integerOf(data, 'totalItems');
  final List<PurchaseRequest> items;
  final int page, totalPages, totalItems;
}

const requestTransitions = {
  'Submitted': ['UnderReview', 'Cancelled'],
  'UnderReview': ['QuotationCollection', 'Rejected', 'Cancelled'],
  'QuotationCollection': ['Evaluation', 'Rejected', 'Cancelled'],
  'Evaluation': ['QuotationCollection', 'Rejected', 'Cancelled'],
  'Approved': ['Evaluation', 'Cancelled'],
};

abstract interface class RequestRepository {
  Future<RequestPage> list({String status = '', int page = 1});
  Future<PurchaseRequest> get(String id);
  Future<PurchaseRequest> create(JsonObject payload);
  Future<List<JsonObject>> history(String id);
  Future<void> changeStatus(
    PurchaseRequest request,
    String nextStatus,
    String reason,
  );
  Future<void> attach(PurchaseRequest request, UploadFile file);
  Future<List<JsonObject>> notifications({bool unreadOnly = false});
  Future<void> readNotification(String id);
}
