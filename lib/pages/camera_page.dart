import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import 'package:camera/camera.dart';

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
            // Removed the top status bar
            Expanded(
              child: CameraService(cameras: widget.cameras),
            ),
          ],
        ),
      ),
    );
  }
}