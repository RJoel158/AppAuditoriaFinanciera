class AppConfig {
  /// ☁️ CONFIGURACIÓN DE ALMACENAMIENTO GRATUITO (Cloudinary)
  /// Regístrate gratis en https://cloudinary.com (No pide tarjeta)
  /// 
  /// 1. Pega tu "Cloud Name" del Dashboard de Cloudinary.
  /// 2. Crea un upload preset "Unsigned" en Settings > Upload > Add upload preset.
  static const String cloudinaryCloudName = 'demo'; // Reemplaza con tu Cloud Name (ej: dx1234abc)
  static const String cloudinaryUploadPreset = 'docs_upload_example_preset'; // Reemplaza con tu preset (ej: auditoria_preset)
}
