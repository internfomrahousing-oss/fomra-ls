import '../models/land_lead_legal_document.dart';
import '../utils/legal_document_catalog.dart';
import 'land_lead_legal_service.dart';

/// In-memory index of legal documents for global search + repository screens.
class DocumentIndexService {
  DocumentIndexService._();
  static final instance = DocumentIndexService._();

  List<LandLeadLegalDocument> _docs = const [];
  DateTime? _loadedAt;
  bool _loading = false;

  List<LandLeadLegalDocument> get documents => List.unmodifiable(_docs);

  bool get isStale {
    if (_loadedAt == null) return true;
    return DateTime.now().difference(_loadedAt!) > const Duration(minutes: 5);
  }

  Future<List<LandLeadLegalDocument>> ensureLoaded({bool force = false}) async {
    if (!force && _docs.isNotEmpty && !isStale) return _docs;
    if (_loading) {
      while (_loading) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      return _docs;
    }
    _loading = true;
    try {
      _docs = await LandLeadLegalService.getAllDocuments();
      _loadedAt = DateTime.now();
    } catch (_) {
      // Keep previous cache on failure.
    } finally {
      _loading = false;
    }
    return _docs;
  }

  void invalidate() {
    _loadedAt = null;
  }

  List<LandLeadLegalDocument> search(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _docs.where((d) {
      final cat = LegalDocumentCatalog.classify(d.fileName);
      final num = LegalDocumentCatalog.extractDocumentNumber(d.fileName);
      return d.fileName.toLowerCase().contains(q) ||
          d.leadId.toLowerCase().contains(q) ||
          cat.label.toLowerCase().contains(q) ||
          (num != null && num.toLowerCase().contains(q)) ||
          d.loggedByName.toLowerCase().contains(q);
    }).toList();
  }

  /// Version history: same lead + same category, newest first.
  List<LandLeadLegalDocument> versionsFor(LandLeadLegalDocument doc) {
    final cat = LegalDocumentCatalog.classify(doc.fileName);
    final list = _docs
        .where((d) =>
            d.leadId == doc.leadId &&
            LegalDocumentCatalog.classify(d.fileName) == cat)
        .toList()
      ..sort((a, b) => b.verifiedAt.compareTo(a.verifiedAt));
    return list;
  }
}
