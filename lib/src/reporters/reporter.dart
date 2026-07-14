import '../models/project_report.dart';

/// Common interface for generating reports of the project dependency check.
abstract interface class Reporter {
  /// Renders the [ProjectReport] into a string format.
  String render(ProjectReport report);
}
