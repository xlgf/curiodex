import 'dart:io';
import 'package:curiodex/utils/custom_font_style.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/ml_kit_service.dart';
import '../pages/facts_page.dart';
import 'dart:math' as math;

class CameraService extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraService({super.key, required this.cameras});

  @override
  State<CameraService> createState() => _CameraServiceState();
}

class _CameraServiceState extends State<CameraService> {
  CameraController? _cameraController;
  bool isCameraReady = false;
  String result = 'Detecting...';
  final MLKitService _mlKitService = MLKitService();
  bool isDetecting = false;
  DetectedObject? _lastDetection;
  bool _flashOn = false;
  bool _isCapturing = false;
  bool _isSwitching = false;
  
  // Add this to track if image stream is running
  bool _isImageStreamActive = false;

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
      await _cameraController!.initialize();
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
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized || 
        _isImageStreamActive) {
      return;
    }
    
    try {
      _isImageStreamActive = true;
      _cameraController!.startImageStream((CameraImage image) async {
        if (!isCameraReady || isDetecting || _isSwitching || _isCapturing) return;
        isDetecting = true;
        try {
          await _processImage(image);
        } catch (e) {
          if (mounted) {
            setState(() {
              result = 'Error processing image: $e';
              _lastDetection = null;
            });
          }
        } finally {
          isDetecting = false;
        }
      });
    } catch (e) {
      _isImageStreamActive = false;
      if (mounted) {
        setState(() {
          result = 'Error starting image stream: $e';
          _lastDetection = null;
        });
      }
    }
  }

  // Add this method to properly stop image stream
  Future<void> _stopImageStream() async {
    if (!_isImageStreamActive || _cameraController == null) return;
    
    try {
      await _cameraController!.stopImageStream();
      _isImageStreamActive = false;
      // Add a delay to ensure the stream is fully stopped
      await Future.delayed(Duration(milliseconds: 200));
    } catch (e) {
      _isImageStreamActive = false;
      // ignore: avoid_print
      print('Error stopping image stream: $e');
    }
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      if (!isCameraReady || _cameraController == null) return;
      final List<DetectedObject> detections = await _mlKitService.processImage(image, _cameraController!);

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

  // FIXED METHOD - Proper handling of concurrent captures
  Future<void> _captureAndAnalyze() async {
    // Prevent multiple simultaneous captures
    if (!isCameraReady || _isCapturing || _cameraController == null || _isSwitching) return;
    
    setState(() {
      _isCapturing = true;
    });
    
    try {
      // Properly stop the image stream and wait for it to complete
      await _stopImageStream();

      // Take a high-quality picture
      final XFile photo = await _cameraController!.takePicture();

      // Process the captured image
      final List<DetectedObject> detections = await _mlKitService.processImageFromPath(photo.path);

      if (detections.isNotEmpty) {
        final bestDetection = _mlKitService.getBestDetection(detections);
        if (bestDetection != null && mounted) {
          // Save the image to permanent storage
          String? permanentImagePath = await _saveImagePermanently(photo.path);
          
          // Navigate to facts page WITH the image path
          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => FactsPage(
                detectedObject: bestDetection.label,
                confidence: bestDetection.confidence * 100,
                imagePath: permanentImagePath,
              ),
            ),
          ).then((_) {
            // Restart image stream when returning from facts page
            if (mounted && isCameraReady && _cameraController != null) {
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
        }
        
        // Clean up the temporary photo if no objects detected
        final File photoFile = File(photo.path);
        if (await photoFile.exists()) {
          await photoFile.delete();
        }
        
        // Restart image stream after cleanup
        if (mounted && isCameraReady && _cameraController != null) {
          _startImageStream();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      // Restart image stream on error
      if (mounted && isCameraReady && _cameraController != null) {
        _startImageStream();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<String?> _saveImagePermanently(String tempPath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/curiodex_images');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'captured_$timestamp.jpg';
      final permanentPath = path.join(imagesDir.path, fileName);
      
      // Copy the temporary file to permanent location
      final tempFile = File(tempPath);
      await tempFile.copy(permanentPath);
      
      // Delete the temporary file
      await tempFile.delete();
      
      return permanentPath;
    } catch (e) {
      // ignore: avoid_print
      print('Error saving image permanently: $e');
      return null;
    }
  }

  void _toggleFlash() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    setState(() {
      _flashOn = !_flashOn;
    });
    _cameraController!.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2 || _isSwitching) return;

    setState(() {
      _isSwitching = true;
      isCameraReady = false;
    });

    try {
      // Stop image stream first
      await _stopImageStream();

      int currentCameraIndex = widget.cameras.indexOf(_cameraController!.description);
      int newCameraIndex = (currentCameraIndex + 1) % widget.cameras.length;

      // Dispose the old controller
      await _cameraController?.dispose();
      _cameraController = null;

      // Small delay to ensure disposal is complete
      await Future.delayed(Duration(milliseconds: 200));

      // Create and initialize the new controller
      _cameraController = CameraController(
        widget.cameras[newCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (!mounted) return;
      
      setState(() {
        isCameraReady = true;
        _flashOn = false; // reset flash state
        _isSwitching = false;
      });
      
      // Start image stream after successful initialization
      _startImageStream();
      
    } catch (e) {
      if (mounted) {
        setState(() {
          result = 'Camera switch failed: $e';
          isCameraReady = false;
          _isSwitching = false;
        });
      }
    }
  }

  bool get _isFrontCamera =>
    _cameraController?.description.lensDirection == CameraLensDirection.front;

  @override
  void dispose() {
    _stopImageStream();
    _cameraController?.dispose();
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
                child: (isCameraReady && _cameraController?.value.isInitialized == true)
                    ? (_isFrontCamera
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: CameraPreview(_cameraController!),
                          )
                        : CameraPreview(_cameraController!))
                    : Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: _isSwitching
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white70),
                                    SizedBox(height: 16),
                                    Text(
                                      'Switching camera...',
                                      style: customFontStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                )
                              : Text(
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
              if (!_isSwitching)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ScanBoxPainter(),
                    ),
                  ),
                ),
              // Detection overlay at the top
              if (_lastDetection != null && !_isSwitching)
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Flash button
              IconButton(
                icon: Icon(
                  _flashOn ? Icons.flash_on : Icons.flash_off,
                  color: (_isSwitching || _isCapturing) ? Colors.grey : Colors.white,
                  size: 32,
                ),
                onPressed: (_isSwitching || _isCapturing) ? null : _toggleFlash,
              ),
              // Capture button
              GestureDetector(
                onTap: (_isSwitching || _isCapturing) ? null : _captureAndAnalyze,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (_isSwitching || _isCapturing) ? Colors.grey : Color(0xFFDAA523),
                      width: 5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isSwitching || _isCapturing) ? Colors.grey[300] : Colors.white,
                        border: Border.all(
                          color: Colors.black,
                          width: 3,
                        ),
                      ),
                      child: _isCapturing
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF232323)),
                              ),
                            )
                          : Icon(
                              Icons.search,
                              size: 48,
                              color: (_isSwitching || _isCapturing) ? Colors.grey : Color(0xFF232323),
                            ),
                    ),
                  ),
                ),
              ),
              // Switch camera button
              IconButton(
                icon: Icon(
                  Icons.cameraswitch,
                  color: (_isSwitching || _isCapturing) ? Colors.grey : Colors.white,
                  size: 32,
                ),
                onPressed: (_isSwitching || _isCapturing) ? null : _switchCamera,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ScanBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // ignore: deprecated_member_use
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final double boxSize = size.width * 0.6;
    final double left = (size.width - boxSize) / 2;
    final double top = (size.height - boxSize) / 2;
    final rect = Rect.fromLTWH(left, top, boxSize, boxSize);

    // Draw only corners
    final cornerLength = 32.0;

    // Top left
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, cornerLength), paint);

    // Top right
    canvas.drawLine(rect.topRight, rect.topRight - Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, cornerLength), paint);

    // Bottom left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft - Offset(0, cornerLength), paint);

    // Bottom right
    canvas.drawLine(rect.bottomRight, rect.bottomRight - Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - Offset(0, cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}