import 'dart:async';

import 'package:camera/camera.dart';
import 'package:curiodex/pages/camera_page.dart';
import 'package:curiodex/utils/custom_font_style.dart';
import 'package:flutter/material.dart';

class Splashscreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Splashscreen({super.key, required this.cameras});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {

  @override
  void initState() {
    super.initState();
    // Simulate a delay for splash screen
    Timer(Duration(seconds: 2), () {
      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (context) => CameraPage(cameras: widget.cameras),
        ),
      );
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFDAA523), 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset("assets/icons/curiodex.png", width: 200, height: 200),
            SizedBox(height: 20),
            Text("Curiodex",
                style: logoFontStyle(
                    fontSize: 40,
                    
                    )),
          ],
        ),
      ),


    );
  }
}