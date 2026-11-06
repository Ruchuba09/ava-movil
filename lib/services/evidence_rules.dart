/// Reglas de evidencia de Laravel (`CrearEventoRequest` y `CerrarEventoRequest`).
const List<String> evidenceExtensions = [
  'jpg',
  'jpeg',
  'png',
  'pdf',
  'doc',
  'docx',
];

const int maxEvidenceBytes = 5 * 1024 * 1024;

const String evidenceTypesMessage =
    'Solo se permiten archivos JPG, PNG, PDF, DOC o DOCX.';

bool isAllowedEvidence(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return false;
  return evidenceExtensions.contains(fileName.substring(dot + 1).toLowerCase());
}
