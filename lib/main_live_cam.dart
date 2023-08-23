import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'LoaderState.dart';
import 'package:image/image.dart' as imglib;

class ImageUtils {
  ///
  /// Converts a [CameraImage] in YUV420 format to [image_lib.Image] in RGB format
  ///
  static imglib.Image convertCameraImage(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return convertYUV420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return convertBGRA8888ToImage(cameraImage);
    } else {
      throw Exception('Undefined image type.');
    }
  }

  ///
  /// Converts a [CameraImage] in BGRA888 format to [image_lib.Image] in RGB format
  ///
  static imglib.Image convertBGRA8888ToImage(CameraImage cameraImage) {
    return imglib.Image.fromBytes(
      width: cameraImage.planes[0].width!,
      height: cameraImage.planes[0].height!,
      bytes: cameraImage.planes[0].bytes.buffer,
      order: imglib.ChannelOrder.bgra,
    );
  }

  ///
  /// Converts a [CameraImage] in YUV420 format to [image_lib.Image] in RGB format
  ///
  static imglib.Image convertYUV420ToImage(CameraImage cameraImage) {
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    final yBuffer = cameraImage.planes[0].bytes;
    final uBuffer = cameraImage.planes[1].bytes;
    final vBuffer = cameraImage.planes[2].bytes;

    final int yRowStride = cameraImage.planes[0].bytesPerRow;
    final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final image = imglib.Image(width: imageWidth, height: imageHeight);

    for (int h = 0; h < imageHeight; h++) {
      int uvh = (h / 2).floor();

      for (int w = 0; w < imageWidth; w++) {
        int uvw = (w / 2).floor();

        final yIndex = (h * yRowStride) + (w * yPixelStride);

        // Y plane should have positive values belonging to [0...255]
        final int y = yBuffer[yIndex];

        // U/V Values are subsampled i.e. each pixel in U/V chanel in a
        // YUV_420 image act as chroma value for 4 neighbouring pixels
        final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        // U/V values ideally fall under [-0.5, 0.5] range. To fit them into
        // [0, 255] range they are scaled up and centered to 128.
        // Operation below brings U/V values to [-128, 127].
        final int u = uBuffer[uvIndex];
        final int v = vBuffer[uvIndex];

        // Compute RGB values per formula above.
        int r = (y + v * 1436 / 1024 - 179).round();
        int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
        int b = (y + u * 1814 / 1024 - 227).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        image.setPixelRgb(w, h, r, g, b);
      }
    }

    return image;
  }
}

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Home(),
    );
  }
}


class Home extends StatefulWidget{
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  List<CameraDescription>? cameras; //list out the camera available
  CameraController? controller; //controller for camera
  XFile? image; //for caputred image

  late ModelObjectDetection _objectModel;
  Uint8List? _imageByteStream;
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];
  bool firststate = false;
  bool message = true;
  bool predicting = false;
  File? tempFile ;
  Directory? directory;

  @override
  void initState() {
    loadCamera();
    super.initState();
  }

  loadCamera() async {
    cameras = await availableCameras();
/*
    _objectModel = await FlutterPytorch.loadObjectDetectionModel(
        "assets/yolov5n.torchscript", 80, 640, 640,
        labelPath: "assets/classes.txt");
*/
/*
 //볼펜만 가지고 학습한거.
    _objectModel = await FlutterPytorch.loadObjectDetectionModel(
        "assets/best.torchscript", 17, 640, 640,
        labelPath: "assets/classes2.txt");
*/

    _objectModel = await FlutterPytorch.loadObjectDetectionModel(
        "assets/best_exp35.torchscript", 17, 640, 640,
        labelPath: "assets/classes2.txt");



    if(cameras != null){
      controller = CameraController(cameras![0], ResolutionPreset.medium, enableAudio: false);
      //cameras[0] = first camera, change to 1 to another camera
      controller?.setFlashMode(FlashMode.off);
      controller?.lockCaptureOrientation();

      controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});

        controller?.startImageStream((CameraImage image) async {
          //print('scan start : $predicting' );

          if(!predicting){
            setState(() {
              //update UI
              predicting = true;
            });

            final imglib.Image capturedImage = ImageUtils.convertYUV420ToImage(image);
            imglib.Image orientedImage = imglib.bakeOrientation(capturedImage!);
            orientedImage = imglib.copyRotate(orientedImage, angle: 90);
            //print('이미지 저장');

            _imageByteStream = imglib.encodeJpg(orientedImage);


            objDetect = await _objectModel.getImagePrediction(
                _imageByteStream!,
                minimumScore: 0.35,
                IOUThershold: 0.3);
            //print('이미지 예측 끝');

            objDetect.forEach((element) {
              print({
                "score": element?.score,
                "className": element?.className,
                "class": element?.classIndex,
                "rect": {
                  "left": element?.rect.left,
                  "top": element?.rect.top,
                  "width": element?.rect.width,
                  "height": element?.rect.height,
                  "right": element?.rect.right,
                  "bottom": element?.rect.bottom,
                },
              });
            });

            setState(() {
              //update UI
              predicting = false;
              firststate = true;
            });
          }
        });

      });

    }else{
      print("NO any camera found");
    }
  }

  @override
  Widget build(BuildContext context) {

    return  Scaffold(
      appBar: AppBar(
        title: const Text("Live Camera Preview"),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
          children:[

            SizedBox(
                height:100,
                //width:400,
                child: controller == null?
                const Center(child:Text("Loading Camera...")):
                !controller!.value.isInitialized?
                const Center(
                  child: CircularProgressIndicator(),
                ):
                CameraPreview(controller!)
            ),


            /*
            FutureBuilder(
              future: loadYoloModel(),
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) async {

              }
            )
             */
            /*
            Container( //show captured image
              padding: EdgeInsets.all(30),
              child: image == null?
              Text("No image captured"):
              Image.file(
                File(_image!.path),
                height: 200,
              ),
              //display captured image
            ),
             */
            !firststate
                ? !message ? const LoaderState() : const Text("Select the Camera to Begin Detections")
                : Expanded(
              child: Container(
                  child:
                  //_objectModel.renderBoxesOnImage(_image!, objDetect)
                  //myRenderBoxesOnImage(_image!, objDetect)
                  myRenderBoxesOnByteStreamImage(_imageByteStream!, objDetect)
              ),
            ),


          ]
      ),
    );
  }
}

Widget myRenderBoxesOnByteStreamImage(
    Uint8List _image, List<ResultObjectDetection?> _recognitions,
    {Color? boxesColor, bool showPercentage = true}) {
  //if (_recognitions == null) return Cont;
  //if (_imageHeight == null || _imageWidth == null) return [];

  //double factorX = screen.width;
  //double factorY = _imageHeight / _imageWidth * screen.width;
  //boxesColor ??= Color.fromRGBO(37, 213, 253, 1.0);

  //print(_recognitions.length);

  return LayoutBuilder(builder: (context, constraints) {
    /*
    debugPrint(
        'Max height: ${constraints.maxHeight}, max width: ${constraints.maxWidth}');

     */
    double factorX = constraints.maxWidth;
    double factorY = constraints.maxHeight;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: factorX,
          height: factorY,
          child: Image.memory(
            _image,
            fit: BoxFit.fill,
              gaplessPlayback: true,
            //key: UniqueKey(),
          ),
        ),
        ..._recognitions.map((re) {
          if (re == null) {
            return Container();
          }
          Color usedColor;
          if (boxesColor == null) {
            //change colors for each label
            usedColor = Colors.primaries[
            ((re.className ?? re.classIndex.toString()).length +
                (re.className ?? re.classIndex.toString())
                    .codeUnitAt(0) +
                re.classIndex) %
                Colors.primaries.length];
          } else {
            usedColor = boxesColor;
          }
          /*
          print({
            "left": re.rect.left.toDouble() * factorX,
            "top": re.rect.top.toDouble() * factorY,
            "width": re.rect.width.toDouble() * factorX,
            "height": re.rect.height.toDouble() * factorY,
          });
           */
          return Positioned(
            left: re.rect.left * factorX,
            top: re.rect.top * factorY - 20,
            //width: re.rect.width.toDouble(),
            //height: re.rect.height.toDouble(),

            //left: re?.rect.left.toDouble(),
            //top: re?.rect.top.toDouble(),
            //right: re.rect.right.toDouble(),
            //bottom: re.rect.bottom.toDouble(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  alignment: Alignment.centerRight,
                  color: usedColor,
                  child: Text(
                    (re.className ?? re.classIndex.toString()) +
                        "" +
                        (showPercentage
                            ? (re.score * 100).toStringAsFixed(2) + "%"
                            : ""),
                  ),
                ),
                Container(
                  width: re.rect.width.toDouble() * factorX,
                  height: re.rect.height.toDouble() * factorY,
                  decoration: BoxDecoration(
                      color: usedColor.withOpacity(0.5),
                      border: Border.all(color: usedColor, width: 3),
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                  child: Container(),
                ),
              ],
            ),
            /*
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  border: Border.all(
                    color: boxesColor!,
                    width: 2,
                  ),
                ),
                child: Text(
                  "${re.className ?? re.classIndex} ${(re.score * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    background: Paint()..color = boxesColor!,
                    color: Colors.white,
                    fontSize: 12.0,
                  ),
                ),
              ),*/
          );
        }).toList()
      ],
    );
  });
}