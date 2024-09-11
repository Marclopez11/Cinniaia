import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:gallery_saver/gallery_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomePage({required this.cameras});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late CameraController _cameraController;
  img.Image? _capturedImage;
  Color _redColor = Colors.red;
  Color _greenColor = Colors.green;
  Color _blueColor = Colors.blue;
  List<Map<String, dynamic>> _savedPhotos = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadSavedPhotos();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
    );
    await _cameraController.initialize();
    setState(() {});
  }

  Future<void> _loadSavedPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhotosJson = prefs.getString('savedPhotos');
    if (savedPhotosJson != null) {
      setState(() {
        _savedPhotos =
            List<Map<String, dynamic>>.from(json.decode(savedPhotosJson));
      });
    }
  }

  Future<void> _savePhotoData(
      String path, int redAvg, int greenAvg, int blueAvg) async {
    _savedPhotos.add({
      'path': path,
      'red': redAvg,
      'green': greenAvg,
      'blue': blueAvg,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedPhotos', json.encode(_savedPhotos));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plant Color Analyzer'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        SavedPhotosScreen(savedPhotos: _savedPhotos)),
              );
            },
          ),
        ],
      ),
      body: _buildCameraScreen(),
      floatingActionButton: FloatingActionButton(
        onPressed: _capturePhoto,
        child: Icon(Icons.camera),
        backgroundColor: Colors.green,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraScreen() {
    return Stack(
      children: [
        _cameraController.value.isInitialized
            ? CameraPreview(_cameraController)
            : Container(),
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorIndicator(_redColor, 'R'),
                _buildColorIndicator(_greenColor, 'G'),
                _buildColorIndicator(_blueColor, 'B'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorIndicator(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          '$label: ${(color.opacity * 255).round()}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _capturePhoto() async {
    try {
      final image = await _cameraController.takePicture();
      print('Picture taken: ${image.path}');

      final capturedImage =
          await compute(img.decodeImage, await image.readAsBytes());
      if (capturedImage == null) {
        print('Failed to decode image');
        return;
      }

      final int redAvg = await compute(_calculateAverageColor,
          {'image': capturedImage, 'color': Colors.red});
      final int greenAvg = await compute(_calculateAverageColor,
          {'image': capturedImage, 'color': Colors.green});
      final int blueAvg = await compute(_calculateAverageColor,
          {'image': capturedImage, 'color': Colors.blue});

      print('Color averages: Red=$redAvg, Green=$greenAvg, Blue=$blueAvg');

      // Save image to gallery
      final savedToGallery = await GallerySaver.saveImage(image.path);
      print('Saved to gallery: $savedToGallery');

      // Save photo data
      await _savePhotoData(image.path, redAvg, greenAvg, blueAvg);

      setState(() {
        _capturedImage = capturedImage;
        _redColor = Colors.red.withOpacity(redAvg / 255);
        _greenColor = Colors.green.withOpacity(greenAvg / 255);
        _blueColor = Colors.blue.withOpacity(blueAvg / 255);
      });
    } catch (e) {
      print('Error capturing photo: $e');
      // Mostrar un mensaje de error al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar la foto: $e')),
      );
    }
  }

  static int _calculateAverageColor(Map<String, dynamic> args) {
    final img.Image image = args['image'];
    final Color color = args['color'];
    final int width = image.width;
    final int height = image.height;

    int colorSum = 0;
    int pixelCount = 0;

    for (int w = 0; w < width; w++) {
      for (int h = 0; h < height; h++) {
        final pixel = image.getPixel(w, h);
        if (color == Colors.red) {
          colorSum += pixel.r.toInt();
        } else if (color == Colors.green) {
          colorSum += pixel.g.toInt();
        } else if (color == Colors.blue) {
          colorSum += pixel.b.toInt();
        }
        pixelCount++;
      }
    }

    return (colorSum / pixelCount).round();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}

class SavedPhotosScreen extends StatelessWidget {
  final List<Map<String, dynamic>> savedPhotos;

  SavedPhotosScreen({required this.savedPhotos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Photos'),
        backgroundColor: Colors.green,
      ),
      body: ListView.builder(
        itemCount: savedPhotos.length,
        itemBuilder: (context, index) {
          final photo = savedPhotos[index];
          return ListTile(
            leading: Image.file(File(photo['path']),
                width: 50, height: 50, fit: BoxFit.cover),
            title: Text('Photo ${index + 1}'),
            subtitle: Text(
                'R: ${photo['red']}, G: ${photo['green']}, B: ${photo['blue']}'),
          );
        },
      ),
    );
  }
}
