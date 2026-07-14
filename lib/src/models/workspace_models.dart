/// Representation of package constraint mismatches across workspace projects.
class WorkspaceConstraintMismatch {
  final String packageName;
  final String section; // 'dependencies' or 'dev_dependencies'
  final Map<String, String> constraintsByProject; // projectPath -> constraint

  const WorkspaceConstraintMismatch({
    required this.packageName,
    required this.section,
    required this.constraintsByProject,
  });

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'section': section,
        'constraintsByProject': constraintsByProject,
      };
}
