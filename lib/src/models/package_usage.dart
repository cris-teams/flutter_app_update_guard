/// Representation of package usages across project code files.
class PackageUsage {
  final String packageName;
  final List<String> productionFiles;
  final List<String> testFiles;
  final List<String> integrationTestFiles;
  final List<String> exampleFiles;

  const PackageUsage({
    required this.packageName,
    required this.productionFiles,
    required this.testFiles,
    required this.integrationTestFiles,
    required this.exampleFiles,
  });

  /// Factory constructor representing zero usage.
  factory PackageUsage.empty(String packageName) => PackageUsage(
        packageName: packageName,
        productionFiles: const [],
        testFiles: const [],
        integrationTestFiles: const [],
        exampleFiles: const [],
      );

  int get totalFiles =>
      productionFiles.length +
      testFiles.length +
      integrationTestFiles.length +
      exampleFiles.length;

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'productionFiles': productionFiles,
        'testFiles': testFiles,
        'integrationTestFiles': integrationTestFiles,
        'exampleFiles': exampleFiles,
        'totalFiles': totalFiles,
      };
}
