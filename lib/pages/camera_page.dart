import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import 'package:camera/camera.dart';
import '../utils/custom_font_style.dart';
class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraPage({super.key, required this.cameras});
  @override
  State<CameraPage> createState() => _CameraPageState();
}
class _CameraPageState extends State<CameraPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Status Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFDAA523),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'CURIODEX',
                        style: customFontStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                         
                        ),
                      ),
                    ),
                  ),
                  // Optionally, add icons to left/right if needed
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: Icon(Icons.settings, color: Colors.white),
                  // ),
                ],
              ),
            ),
            // CameraService handles camera and controls
            Expanded(
              child: CameraService(cameras: widget.cameras),
            ),
          ],
        ),
      ),
    );
  }
}