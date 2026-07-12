/// Canonical legal / survey document categories for the central repository.
enum LegalDocCategory {
  patta,
  chitta,
  fmb,
  ec,
  saleDeed,
  surveyReport,
  other,
}

extension LegalDocCategoryX on LegalDocCategory {
  String get label => switch (this) {
        LegalDocCategory.patta => 'Patta',
        LegalDocCategory.chitta => 'Chitta',
        LegalDocCategory.fmb => 'FMB',
        LegalDocCategory.ec => 'EC',
        LegalDocCategory.saleDeed => 'Sale Deed',
        LegalDocCategory.surveyReport => 'Survey Reports',
        LegalDocCategory.other => 'Other',
      };

  String get storagePrefix => switch (this) {
        LegalDocCategory.patta => 'Patta',
        LegalDocCategory.chitta => 'Chitta',
        LegalDocCategory.fmb => 'FMB',
        LegalDocCategory.ec => 'EC',
        LegalDocCategory.saleDeed => 'SaleDeed',
        LegalDocCategory.surveyReport => 'SurveyReport',
        LegalDocCategory.other => 'Doc',
      };
}

abstract final class LegalDocumentCatalog {
  static const managedCategories = [
    LegalDocCategory.patta,
    LegalDocCategory.chitta,
    LegalDocCategory.fmb,
    LegalDocCategory.ec,
    LegalDocCategory.saleDeed,
    LegalDocCategory.surveyReport,
  ];

  static LegalDocCategory classify(String fileName) {
    final n = fileName.toLowerCase();
    if (n.contains('patta')) return LegalDocCategory.patta;
    if (n.contains('chitta') || n.contains('adangal')) {
      return LegalDocCategory.chitta;
    }
    if (n.contains('fmb') || n.contains('field measurement')) {
      return LegalDocCategory.fmb;
    }
    if (RegExp(r'\bec\b').hasMatch(n) ||
        n.contains('encumbrance') ||
        n.contains(' e.c')) {
      return LegalDocCategory.ec;
    }
    if (n.contains('sale') && n.contains('deed')) {
      return LegalDocCategory.saleDeed;
    }
    if (n.contains('survey') || n.contains('sketch')) {
      return LegalDocCategory.surveyReport;
    }
    return LegalDocCategory.other;
  }

  /// Digits / alphanumerics treated as a document number in the filename.
  static String? extractDocumentNumber(String fileName) {
    final base = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final match = RegExp(
      r'(?:no|num|number|#|doc)?[\s_\-]*([A-Za-z0-9]{4,})',
      caseSensitive: false,
    ).allMatches(base);
    if (match.isEmpty) return null;
    // Prefer the last substantial token (often the id after type prefix).
    return match.last.group(1);
  }
}
