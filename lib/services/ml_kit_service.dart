import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class MLKitService {
  late ImageLabeler _imageLabeler;
  bool _isInitialized = false;

  // Initialize the ML Kit Image Labeler
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final options = ImageLabelerOptions(
        confidenceThreshold: 0.5,
      );
      _imageLabeler = ImageLabeler(options: options);
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize ML Kit: $e');
    }
  }

  // Process image from camera stream
  Future<List<DetectedObject>> processImage(CameraImage image, CameraController controller) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Take a picture and save it temporarily
      final Directory tempDir = await getTemporaryDirectory();
      final String imagePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final XFile xFile = await controller.takePicture();
      await xFile.saveTo(imagePath);

      // Create InputImage from the saved file
      final inputImage = InputImage.fromFilePath(imagePath);
      
      // Process the image
      final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
      
      // Clean up temporary file
      final File tempFile = File(imagePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      // Convert ImageLabel to DetectedObject
      return labels.map((label) => DetectedObject(
        label: label.label,
        confidence: label.confidence,
      )).toList();
      
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  // Process image from file path
  Future<List<DetectedObject>> processImageFromPath(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
      
      return labels.map((label) => DetectedObject(
        label: label.label,
        confidence: label.confidence,
      )).toList();
      
    } catch (e) {
      throw Exception('Failed to process image from path: $e');
    }
  }

  // Process image from File
  Future<List<DetectedObject>> processImageFromFile(File imageFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
      
      return labels.map((label) => DetectedObject(
        label: label.label,
        confidence: label.confidence,
      )).toList();
      
    } catch (e) {
      throw Exception('Failed to process image from file: $e');
    }
  }

  // Get the most confident detection
  DetectedObject? getBestDetection(List<DetectedObject> detections) {
    if (detections.isEmpty) return null;
    
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detections.first;
  }

  // Filter detections by confidence threshold
  List<DetectedObject> filterByConfidence(List<DetectedObject> detections, double threshold) {
    return detections.where((detection) => detection.confidence >= threshold).toList();
  }

  // Get formatted string of all detections
  String getDetectionsString(List<DetectedObject> detections) {
    if (detections.isEmpty) return 'No objects detected';
    
    return detections
        .map((detection) => "${detection.label} (${(detection.confidence * 100).toStringAsFixed(1)}%)")
        .join(', ');
  }

  // Check if service is initialized
  bool get isInitialized => _isInitialized;

  // Dispose of resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _imageLabeler.close();
      _isInitialized = false;
    }
  }
}

// Data class to represent detected objects
class DetectedObject {
  final String label;
  final double confidence;

  DetectedObject({
    required this.label,
    required this.confidence,
  });

  @override
  String toString() {
    return 'DetectedObject(label: $label, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }

  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'confidence': confidence,
    };
  }

  // Create from map for deserialization
  factory DetectedObject.fromMap(Map<String, dynamic> map) {
    return DetectedObject(
      label: map['label'] ?? '',
      confidence: (map['confidence'] ?? 0.0).toDouble(),
    );
  }
}