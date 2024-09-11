import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomePage({required this.cameras});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late CameraController _cameraController;
  int _selectedIndex = 0;
  img.Image? _capturedImage;
  Color _redColor = Colors.red;
  Color _greenColor = Colors.green;
  Color _blueColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
    );
    await _cameraController.initialize();
    _cameraController.startImageStream(_processImage);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return _buildCameraScreen();
    } else {
      return _buildSettingsScreen();
    }
  }

  Widget _buildCameraScreen() {
    return Stack(
      children: [
        _cameraController.value.isInitialized
            ? CameraPreview(_cameraController)
            : Container(),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorIndicator(
                    _redColor, (_capturedImage?.getPixel(0, 0).r ?? 0).toInt()),
                _buildColorIndicator(_greenColor,
                    (_capturedImage?.getPixel(0, 0).g ?? 0).toInt()),
                _buildColorIndicator(_blueColor,
                    (_capturedImage?.getPixel(0, 0).b ?? 0).toInt()),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton(
              onPressed: _capturePhoto,
              child: Text('Capture Photo'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorIndicator(Color color, int value) {
    return Container(
      width: 60,
      height: 200,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Expanded(
            child: FractionallySizedBox(
              heightFactor: value / 255,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return Center(
      child: Text('Settings Screen'),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _processImage(CameraImage cameraImage) async {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final image = img.Image(width: width, height: height);

    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

      int redSum = 0;
      int greenSum = 0;
      int blueSum = 0;
      int pixelCount = 0;

      for (int w = 0; w < width; w++) {
        for (int h = 0; h < height; h++) {
          final int uvIndex =
              uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
          final int index = h * width + w;

          final y = cameraImage.planes[0].bytes[index];
          final u = cameraImage.planes[1].bytes[uvIndex];
          final v = cameraImage.planes[2].bytes[uvIndex];

          final int r = (y + 1.402 * (v - 128)).round().clamp(0, 255).toInt();
          final int g = (y - 0.344 * (u - 128) - 0.714 * (v - 128))
              .round()
              .clamp(0, 255)
              .toInt();
          final int b = (y + 1.772 * (u - 128)).round().clamp(0, 255).toInt();

          image.setPixelRgba(w, h, r, g, b, 255);

          redSum += r;
          greenSum += g;
          blueSum += b;
          pixelCount++;
        }
      }

      final int redAvg = (redSum / pixelCount).round();
      final int greenAvg = (greenSum / pixelCount).round();
      final int blueAvg = (blueSum / pixelCount).round();

      print('Color averages: Red=$redAvg, Green=$greenAvg, Blue=$blueAvg');

      setState(() {
        _capturedImage = image;
        _redColor = Color.fromRGBO(redAvg, 0, 0, 1);
        _greenColor = Color.fromRGBO(0, greenAvg, 0, 1);
        _blueColor = Color.fromRGBO(0, 0, blueAvg, 1);
      });
    }
  }

  void _capturePhoto() async {
    final image = await _cameraController.takePicture();
    final capturedImage = img.decodeImage(await image.readAsBytes());

    if (capturedImage != null) {
      final int width = capturedImage.width;
      final int height = capturedImage.height;

      int redSum = 0;
      int greenSum = 0;
      int blueSum = 0;
      int pixelCount = 0;

      for (int w = 0; w < width; w++) {
        for (int h = 0; h < height; h++) {
          final pixel = capturedImage.getPixel(w, h);
          redSum += pixel.r.toInt();
          greenSum += pixel.g.toInt();
          blueSum += pixel.b.toInt();
          pixelCount++;
        }
      }

      final int redAvg = (redSum / pixelCount).round();
      final int greenAvg = (greenSum / pixelCount).round();
      final int blueAvg = (blueSum / pixelCount).round();

      print('Color averages: Red=$redAvg, Green=$greenAvg, Blue=$blueAvg');

      setState(() {
        _capturedImage = capturedImage;
        _redColor = Color.fromRGBO(redAvg, 0, 0, 1);
        _greenColor = Color.fromRGBO(0, greenAvg, 0, 1);
        _blueColor = Color.fromRGBO(0, 0, blueAvg, 1);
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}
