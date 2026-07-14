/// Model containing keywords and indicators from package changelog analysis.
class ChangelogAnalysis {
  final bool available;
  final List<String> indicators;
  final String? source;

  const ChangelogAnalysis({
    required this.available,
    required this.indicators,
    this.source,
  });

  Map<String, dynamic> toJson() => {
        'available': available,
        'indicators': indicators,
        if (source != null) 'source': source,
      };
}
