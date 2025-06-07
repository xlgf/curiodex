import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraPage({super.key , required this.cameras});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  //camera implementation
  late CameraController _cameraController;
  bool isCameraReady = false;
  String result = 'Detecting...';
  late ImageLabeler _imageLabeler;
  bool isDetecting = false;


  Future<void> _initializeCameraController() async {
   _cameraController = CameraController(widget.cameras[0],
    ResolutionPreset.ultraHigh,
    enableAudio: false
    );
    await _cameraController.initialize();
    if(!mounted) return;
    setState(() {
      isCameraReady = true;
    });

    _startImageStream();

  }

  void initializeMLKit() {
    final options = ImageLabelerOptions(confidenceThreshold: 0.5);
    _imageLabeler = ImageLabeler(options: options);
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if(isDetecting) return;
      isDetecting = true;
      await _processImage(image);
      isDetecting = false;
    });

    
  }
  Future<void> _processImage(CameraImage image) async {

      try{
        final Directory tempDir = await getTemporaryDirectory();
        final String imagePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File imageFile = File(imagePath);

        final XFile xFile = await _cameraController.takePicture();
        await xFile.saveTo(imagePath);

        final inputImage = InputImage.fromFilePath(imagePath);
        final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);

        String detectedObjects = labels.isNotEmpty ? labels.map((label) => "${label.label} (${(label.confidence * 100).toStringAsFixed(2)}%)").join(', ') : 'No objects detected';
        setState(() {
          result = detectedObjects;
          
        });
      } catch (error) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image'), backgroundColor: Colors.red[100]),
        );
      }
    }

  @override
  void dispose() {
    _cameraController.dispose();
    _imageLabeler.close();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  @override
  void initState() {
    super.initState();
    initializeMLKit();
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection Camera'),
        backgroundColor: Colors.deepPurple[100],
        
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Camera preview widget will be added here
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: isCameraReady
                    ? CameraPreview(_cameraController)
                    : Center(
                        child: Text(
                          result,
                          style: TextStyle(fontSize: 18, color: Colors.red),
                        ),
                      ),
               
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(20), topLeft: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Text("Detected Objects", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                     decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3), // changes position of shadow
                          ),
                        ],
                      ),
                      child: Text(
                        result,
                        style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                    )
                    ),
                  ],
                ),
              ),
            ),
            // Add other widgets like buttons or overlays here
          ],
        ),
      )
    );
  }
}

