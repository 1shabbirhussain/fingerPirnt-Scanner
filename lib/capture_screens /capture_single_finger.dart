import 'dart:typed_data';
import 'package:demo_project/capture_screens%20/captured_file_view.dart';
import 'package:demo_project/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:biopassid_fingerprint_sdk/biopassid_fingerprint_sdk.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SingleFingerCapturePage extends StatefulWidget {
  const SingleFingerCapturePage({super.key});

  @override
  _SingleFingerCapturePageState createState() =>
      _SingleFingerCapturePageState();
}

class _SingleFingerCapturePageState extends State<SingleFingerCapturePage> {
  late FingerprintController controller;
  List<Uint8List> firstCapturedImages = [];
  List<Uint8List> secondCapturedImages = [];
  int captureCount = 0;
  bool captureButtonEnabled = true;
  bool verifyButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    final config = FingerprintConfig(
      numberFingersToCapture: 1,
      licenseKey: 'ZUGZ-CHWQ-2KJR-PQFI',
      outputType: FingerprintOutputType.captureAndSegmentation,
      captureType: FingerprintCaptureType.leftHandFingers,
      helpText: FingerprintHelpTextOptions(
        messages: FingerprintHelpTextMessages(
          leftHandMessage:
              "Place left hand finger \nuntil the marker is centered.",
        ),
      ),
    );
    controller = FingerprintController(
      config: config,
      onFingerCapture: (images, error) async {
        if (error != null) {
          debugPrint('onFingerCaptured: $error');
        } else {
          debugPrint('onFingerCaptured: $images ${images[0][0]}');
          setState(() {
            List<Uint8List> processedImages = images.map((imageBytes) {
              img.Image processedImage = processImage(imageBytes);
              return Uint8List.fromList(img.encodePng(processedImage));
            }).toList();

            // Store in the appropriate list based on the capture count
            if (captureCount == 1) {
              firstCapturedImages.addAll(processedImages);
            } else if (captureCount == 2) {
              secondCapturedImages.addAll(processedImages);
              captureButtonEnabled = false;
              verifyButtonEnabled =
                  true; // Enable verify button after second capture
            }
          });
        }
      },
      onStatusChanged: (FingerprintCaptureState state) {
        debugPrint('onStatusChanged: $state');
      },
      onFingerDetected: (List<Rect> fingerRects) {
        debugPrint('onFingerDetected: $fingerRects');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Finger'),
      ),
      body: Column(
        children: [
          Center(
            child: ElevatedButton(
              onPressed: captureButtonEnabled ? takeFingerprint : null,
              child: const Text('Capture Finger'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: ElevatedButton(
              onPressed: clearCapturedData,
              child: const Text('Clear Data'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: ElevatedButton(
              // onPressed: ()async{
              //    final tempDir = await getTemporaryDirectory();
              //   final file1 = await File('${tempDir.path}/finger1.png').create();
              //   final file2 = await File('${tempDir.path}/finger2.png').create();
              //   await file1.writeAsBytes(firstCapturedImages[1]); 
              //   await file2.writeAsBytes(secondCapturedImages[1]).then((value) => Navigator.push(
              //     context,
              //     MaterialPageRoute(builder: (context) => CapturedFiles(file1: file1, file2: file2)),
              //   ));
                
               
              // },
              onPressed: verifyButtonEnabled ? verifyFingers : null,
              child: const Text('Verify Fingers'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount:
                  firstCapturedImages.length + secondCapturedImages.length,
              itemBuilder: (context, index) {
                if (index < firstCapturedImages.length) {
                  return Image.memory(firstCapturedImages[1]);
                } else {
                  return Image.memory(
                      secondCapturedImages[1]);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  //METHODS TO HANDLE FINGERPRINT CAPTURE

  void takeFingerprint() async {
    if (captureButtonEnabled) {
      captureCount++;
      await controller.takeFingerprint();
    }
  }

  void clearCapturedData() {
    setState(() {
      firstCapturedImages.clear();
      secondCapturedImages.clear();
      captureCount = 0;
      captureButtonEnabled = true;
      verifyButtonEnabled = false; // Disable verify button
    });
  }

  img.Image processImage(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw ArgumentError('Unable to decode image');
    }

    img.Image grayscale = img.grayscale(image);
    img.Image thresholdImage = img.Image(grayscale.width, grayscale.height);

    const int thresholdValue = 110;

    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        int pixel = grayscale.getPixel(x, y);
        int value = img.getRed(pixel);

        if (value > thresholdValue) {
          thresholdImage.setPixel(x, y, img.getColor(255, 255, 255)); // White
        } else {
          thresholdImage.setPixel(x, y, img.getColor(0, 0, 0)); // Black
        }
      }
    }
    //resize image
    img.Image resizedImage =img.copyResize(thresholdImage, width: 200, height: 200,);
     // Compress the image to reduce the size
  List<int> compressedImageBytes = img.encodeJpg(resizedImage, quality: 40);

  // Check the size and adjust if necessary
  while (compressedImageBytes.length > 200 * 1024) {
    // Reduce quality to reduce size
    compressedImageBytes = img.encodeJpg(resizedImage, quality: 40);
  }

  // Decode the compressed image bytes back into an img.Image object
  img.Image finalImage = img.decodeImage(compressedImageBytes)!;

  return finalImage;
    // return resizedImage;
  }

  Future<void> verifyFingers() async {
    try {
      // Ensure there are images to save
      if (firstCapturedImages.isEmpty || secondCapturedImages.isEmpty) {
        throw Exception('No images captured for verification');
      }

      // Save captured images to temporary files
      final tempDir = await getTemporaryDirectory();
      final file1 = await File('${tempDir.path}/finger1.jpg').create();
      final file2 = await File('${tempDir.path}/finger2.jpg').create();
      await file1.writeAsBytes(firstCapturedImages[1]); 
      await file2.writeAsBytes(secondCapturedImages[1]);

      // Use ApiService to upload images
      ApiService apiService =
          ApiService(baseUrl: 'http://bioapi.fscscampus.com/api/values');
      await apiService.uploadImages(file1, file2);
      
    } catch (e) {
      debugPrint('Error during verification: $e');
    }
  }
}
