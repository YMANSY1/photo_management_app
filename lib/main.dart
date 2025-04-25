import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(PhotoManagementApp());
}

class PhotoManagementApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Manager',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Arial'),
      home: PhotoGridScreen(),
    );
  }
}

class PhotoGridScreen extends StatefulWidget {
  @override
  _PhotoGridScreenState createState() => _PhotoGridScreenState();
}

class _PhotoGridScreenState extends State<PhotoGridScreen> {
  List<File> _imageList = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _errorMessage = '';
  String _imagesDirectoryPath =
      '/storage/emulated/0/Pictures'; // Default, will be updated.

  @override
  void initState() {
    super.initState();
    _loadImages();
    _initImagesDirectory(); // Initialize the directory.
  }

  // Initialize the directory where images will be saved.
  Future<void> _initImagesDirectory() async {
    try {
      final directory = Directory(_imagesDirectoryPath);
      if (!directory.existsSync()) {
        await directory.create(recursive: true); // Create if it doesn't exist.
      }
      setState(() {
        _imagesDirectoryPath = directory.path;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize image directory: ${e.toString()}';
        _isLoading = false;
      });
      print('Error initializing image directory: $e');
    }
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Storage permission is required to access images.';
        });
        return;
      }
    }

    try {
      final directory = Directory(_imagesDirectoryPath);

      if (!directory.existsSync()) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Image directory does not exist or is not accessible.';
        });
        return;
      }

      final List<FileSystemEntity> files = directory.listSync();

      _imageList = files
          .whereType<File>()
          .where(
            (file) =>
                file.path.toLowerCase().endsWith('.jpg') ||
                file.path.toLowerCase().endsWith('.jpeg') ||
                file.path.toLowerCase().endsWith('.png'),
          )
          .toList();

      _imageList.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading images: ${e.toString()}';
      });
      print('Error loading images: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _captureImage() async {
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to capture images.'),
            ),
          );
        }
        return;
      }
    }

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        // Construct the new file path.
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final newImagePath = '$_imagesDirectoryPath/IMG_$timestamp.jpg';
        final File newImageFile = File(newImagePath);

        // Copy the image to the new location.
        final File savedImage = await File(pickedFile.path).copy(newImagePath);

        setState(() {
          _imageList.insert(0, savedImage); // Use the saved image.
        });
        _loadImages(); // Refresh to include file in storage
      } else {
        print('No image selected.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: ${e.toString()}')),
        );
      }
      print('Error capturing image: $e');
    }
  }

  void _showImageDialog(File imageFile) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(imageFile),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Grid'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _imageList.isEmpty
                  ? const Center(child: Text('No images found.'))
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MasonryGridView.count(
                        crossAxisCount: 4,
                        itemCount: _imageList.length,
                        mainAxisSpacing: 8.0,
                        crossAxisSpacing: 8.0,
                        itemBuilder: (context, index) {
                          final imageFile = _imageList[index];
                          return GestureDetector(
                            onTap: () {
                              _showImageDialog(imageFile);
                            },
                            child: Card(
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.file(imageFile, fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureImage,
        tooltip: 'Capture Image',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
