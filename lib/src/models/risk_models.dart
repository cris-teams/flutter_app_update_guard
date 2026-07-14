/// Enum representing the safety levels of dependencies.
enum RiskLevel {
  safe(0),
  low(20),
  medium(50),
  high(75),
  critical(100);

  final int maxScore;
  const RiskLevel(this.maxScore);

  /// Parse a RiskLevel from string, case-insensitive.
  static RiskLevel parse(String val) {
    final lower = val.toLowerCase();
    for (final level in RiskLevel.values) {
      if (level.name == lower) {
        return level;
      }
    }
    throw ArgumentError('Invalid RiskLevel: $val');
  }

  /// Resolve RiskLevel from a numeric score (0 to 100).
  static RiskLevel fromScore(int score) {
    if (score <= 0) return RiskLevel.safe;
    if (score <= 20) return RiskLevel.low;
    if (score <= 50) return RiskLevel.medium;
    if (score <= 75) return RiskLevel.high;
    return RiskLevel.critical;
  }
}

/// A specific reason why a dependency update holds risk.
class RiskReason {
  final String code;
  final String message;
  final int score;

  const RiskReason({
    required this.code,
    required this.message,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'score': score,
      };
}

/// Aggregated risk score, level, and evaluation reasons.
class DependencyRisk {
  final int score;
  final RiskLevel level;
  final List<RiskReason> reasons;

  const DependencyRisk({
    required this.score,
    required this.level,
    required this.reasons,
  });

  /// Utility constructor for safe (no risk) states.
  factory DependencyRisk.safe() => const DependencyRisk(
        score: 0,
        level: RiskLevel.safe,
        reasons: [],
      );

  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level.name,
        'reasons': reasons.map((r) => r.toJson()).toList(),
      };
}
