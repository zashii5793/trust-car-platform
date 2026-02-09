/// Standardized trace names for performance monitoring
///
/// Using consistent names ensures proper grouping in Firebase Console
/// and makes it easier to analyze metrics across the application.
class TraceNames {
  TraceNames._();

  // ============================================
  // Firebase Firestore Operations
  // ============================================

  // Vehicle operations
  static const addVehicle = 'firebase.vehicle.add';
  static const updateVehicle = 'firebase.vehicle.update';
  static const deleteVehicle = 'firebase.vehicle.delete';
  static const getVehicle = 'firebase.vehicle.get';
  static const getUserVehicles = 'firebase.vehicle.list';
  static const isLicensePlateExists = 'firebase.vehicle.check_plate';

  // Maintenance operations
  static const addMaintenanceRecord = 'firebase.maintenance.add';
  static const updateMaintenanceRecord = 'firebase.maintenance.update';
  static const deleteMaintenanceRecord = 'firebase.maintenance.delete';
  static const getMaintenanceRecords = 'firebase.maintenance.list';
  static const getMaintenanceRecordsBatch = 'firebase.maintenance.batch';

  // ============================================
  // Firebase Storage Operations
  // ============================================

  static const uploadImage = 'storage.image.upload';
  static const uploadImageBytes = 'storage.image.upload_bytes';
  static const uploadProcessedImage = 'storage.image.upload_processed';
  static const deleteImage = 'storage.image.delete';

  // ============================================
  // Authentication Operations
  // ============================================

  static const signUp = 'auth.signup';
  static const signInEmail = 'auth.signin.email';
  static const signInGoogle = 'auth.signin.google';
  static const signOut = 'auth.signout';
  static const sendPasswordReset = 'auth.password_reset';
  static const getUserProfile = 'auth.profile.get';
  static const updateUserProfile = 'auth.profile.update';
  static const updateNotificationSettings = 'auth.notification_settings.update';

  // ============================================
  // CPU-Intensive Operations
  // ============================================

  static const compressImage = 'image.compress';
  static const validateImage = 'image.validate';
  static const processImage = 'image.process';

  // OCR operations
  static const ocrVehicleCertificate = 'ocr.vehicle_certificate';
  static const ocrInvoice = 'ocr.invoice';

  // PDF generation
  static const generatePdf = 'pdf.generate';

  // Recommendation calculation
  static const calculateRecommendations = 'recommendation.calculate';

  // ============================================
  // Screen Navigation
  // ============================================

  static const screenHomeLoad = 'screen.home.load';
  static const screenVehicleDetailLoad = 'screen.vehicle_detail.load';
  static const screenMaintenanceListLoad = 'screen.maintenance_list.load';
}
