/// Model representing a violation of configured update policies.
class PolicyViolation {
  final String code;
  final String message;
  final String? packageName;

  const PolicyViolation({
    required this.code,
    required this.message,
    this.packageName,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (packageName != null) 'packageName': packageName,
      };
}
