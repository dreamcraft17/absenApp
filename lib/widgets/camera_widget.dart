import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraWidget extends StatefulWidget {
  final Function(File) onImageCaptured;

  CameraWidget({required this.onImageCaptured});

  @override
  _CameraWidgetState createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  final ImagePicker _picker = ImagePicker();
  File? _image;

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image != null) {
        setState(() {
          _image = File(image.path);
        });
        widget.onImageCaptured(_image!);
      }
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _image != null
            ? Image.file(_image!)
            : Placeholder(
                fallbackHeight: 200,
                fallbackWidth: double.infinity,
              ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _takePicture,
          child: Text('Ambil Foto'),
        ),
      ],
    );
  }
}