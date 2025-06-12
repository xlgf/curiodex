import 'dart:io';
import 'package:curiodex/utils/custom_font_style.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ml_kit_service.dart';
import '../pages/facts_page.dart';

class CameraService extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraService({super.key, required this.cameras});

  @override
  State<CameraService> createState() => _CameraServiceState();
}

class _CameraServiceState extends State<CameraService> {
  late CameraController _cameraController;
  bool isCameraReady = false;
  String result = 'Detecting...';
  final MLKitService _mlKitService = MLKitService();
  bool isDetecting = false;
  DetectedObject? _lastDetection;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _requestCameraPermission().then((_) {
      if (widget.cameras.isNotEmpty) {
        _initializeCameraController();
      } else {
        setState(() {
          isCameraReady = false;
          result = 'No cameras found';
        });
      }
    });
  }

  Future<void> _initializeServices() async {
    try {
      await _mlKitService.initialize();
    } catch (e) {
      setState(() {
        result = 'Failed to initialize ML Kit: $e';
      });
    }
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  Future<void> _initializeCameraController() async {
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    try {
      await _cameraController.initialize();
      if (!mounted) return;
      setState(() {
        isCameraReady = true;
      });
      _startImageStream();
    } catch (e) {
      setState(() {
        result = 'Camera initialization failed: $e';
      });
    }
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (isDetecting) return;
      isDetecting = true;
      await _processImage(image);
      isDetecting = false;
    });
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final List<DetectedObject> detections = await _mlKitService.processImage(image, _cameraController);
      
      if (detections.isNotEmpty) {
        final bestDetection = _mlKitService.getBestDetection(detections);
        if (bestDetection != null) {
          _lastDetection = bestDetection;
          setState(() {
            result = _mlKitService.getDetectionsString(detections);
          });
        }
      } else {
        setState(() {
          result = 'No objects detected';
          _lastDetection = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          result = 'Detection error: $error';
          _lastDetection = null;
        });
      }
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (!isCameraReady) return;
    
    try {
      // Stop the image stream temporarily
      await _cameraController.stopImageStream();
      
      // Take a high-quality picture
      final XFile photo = await _cameraController.takePicture();
      
      // Process the captured image
      final List<DetectedObject> detections = await _mlKitService.processImageFromPath(photo.path);
      
      if (detections.isNotEmpty) {
        final bestDetection = _mlKitService.getBestDetection(detections);
        if (bestDetection != null && mounted) {
          // Navigate to facts page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FactsPage(
                detectedObject: bestDetection.label,
                confidence: bestDetection.confidence * 100,
              ),
            ),
          ).then((_) {
            // Restart image stream when returning from facts page
            if (isCameraReady) {
              _startImageStream();
            }
          });
        }
      } else {
        // Show snackbar if no objects detected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No objects detected. Try pointing at a clear object.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          // Restart image stream
          _startImageStream();
        }
      }
      
      // Clean up the temporary photo
      final File photoFile = File(photo.path);
      if (await photoFile.exists()) {
        await photoFile.delete();
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Restart image stream on error
        if (isCameraReady) {
          _startImageStream();
        }
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _mlKitService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Camera Preview fills available space
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: isCameraReady
                    ? CameraPreview(_cameraController)
                    : Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Text(
                            result,
                            style: customFontStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
              // Detection overlay at the top
              if (_lastDetection != null)
                Positioned(
                  top: 24,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_lastDetection!.label} (${(_lastDetection!.confidence * 100).toStringAsFixed(1)}%)',
                      style: customFontStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Bottom Controls
        Padding(
          padding: const EdgeInsets.only(bottom: 5, top: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _captureAndAnalyze,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFFDAA523), // gold border
                      width: 5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.black,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.search,
                        size: 48,
                        color: Color(0xFF232323),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}