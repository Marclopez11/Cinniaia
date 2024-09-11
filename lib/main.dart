import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'home_page.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Color Analyzer',
      home: HomePage(cameras: cameras),
    );
  }
}
