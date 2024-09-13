import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_linux_bindings_generated.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart';
import 'package:image_picker/image_picker.dart';

class CameraLinux {
  late CameraLinuxBindings _bindings;

  CameraLinux() {
    final dylib = DynamicLibrary.open('libcamera_linux.so');
    _bindings = CameraLinuxBindings(dylib);
  }

  // Open Default Camera
  Future<void> initializeCamera() async {
    _bindings.startVideoCaptureInThread();
  }

  // Close The Camera
  void stopCamera() {
    _bindings.stopVideoCapture();
  }

  // Take a Picture and return XFile
  Future<XFile> takePicture() async {
    final Uint8List imageBytes = await getImageData();
    final base64String = uint8ListToBase64Url(imageBytes);

    // Convert Base64 to Image File
    final imageData = base64Decode(base64String);

    final fileName = 'picture_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(imageData);

    return XFile(filePath);
  }

  // Get Image Bytes
  Future<Uint8List> getImageData() async {
    final lengthPtr = calloc<Int>();
    Pointer<Uint8> framePointer = _bindings.getLatestFrameBytes(lengthPtr);
    return getLatestFrameData(framePointer, lengthPtr.value);
  }

  // Convert Frame Into Base64
  String uint8ListToBase64Url(Uint8List data) {
    String base64String = base64Encode(data);

    String base64Url = base64String
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');

    int requiredLength = (4 - (base64Url.length % 4)) % 4;
    return base64Url + '=' * requiredLength;
  }

  // Capture The Frame
  Future<String> captureImage() async {
    final lengthPtr = calloc<Int>();
    Pointer<Uint8> framePointer = _bindings.getLatestFrameBytes(lengthPtr);
    final latestFrame = getLatestFrameData(framePointer, lengthPtr.value);
    final base64Image = uint8ListToBase64Url(latestFrame);
    return base64Image;
  }

  // Get The Latest Frame
  Uint8List getLatestFrameData(Pointer<Uint8> framePointer, frameSize) {
    List<int> frameList = framePointer.asTypedList(frameSize);
    return Uint8List.fromList(frameList);
  }
}
