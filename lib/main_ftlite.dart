import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'LoaderState.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

Future<void> main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Home(),
    );
  }
}


class Home extends StatefulWidget{
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  List<CameraDescription>? cameras; //list out the camera available
  CameraController? controller; //controller for camera
  XFile? image; //for caputred image

  late ModelObjectDetection _objectModel;
  String? _imagePrediction;
  List? _prediction;
  File? _image;
  ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];
  bool firststate = false;
  bool message = true;
  bool predicting = false;
  late CameraImage cameraImage;

  @override
  void initState() {
    loadCamera();
    super.initState();
  }

  void handleTimeout() {
    // callback function
    // Do some work.
    setState(() {
      firststate = true;
    });
  }


  loadCamera() async {
    cameras = await availableCameras();
    /*
    _objectModel = await FlutterPytorch.loadObjectDetectionModel(
        "assets/yolov5n.torchscript", 80, 640, 640,
        labelPath: "assets/classes.txt");

     */

    if(cameras != null){
      controller = CameraController(cameras![0], ResolutionPreset.max);
      //cameras[0] = first camera, change to 1 to another camera

      controller!.initialize().then((_) async {
        if (!mounted) {
          return;
        }
        await controller?.startImageStream((CameraImage image) async {
          /*
          if (predicting) {
          //print("here processing");
            return;
          }

          setState(() {
            predicting = true;
          });

          cameraImage = image;
          runModel();


          setState(() {
            predicting = false;
            //_image = File(_image_test!.path);
          });

          //scheduleTimeout(5 * 1000);

        */
        });
        setState(() {});


      });
      
    }else{
      print("NO any camera found");
    }
  }

  Timer scheduleTimeout([int milliseconds = 10000]) =>
      Timer(Duration(milliseconds: milliseconds), handleTimeout);


  @override
  Widget build(BuildContext context) {

    return  Scaffold(
      appBar: AppBar(
        title: Text("Live Camera Preview"),
        backgroundColor: Colors.redAccent,
      ),
      body: Container(
          child: Column(
              children:[
                Container(
                    height:500,
                    //width:400,
                    child: controller == null?
                    Center(child:Text("Loading Camera...")):
                    !controller!.value.isInitialized?
                    Center(
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
                /*
                !firststate
                    ? !message ? LoaderState() : Text("Select the Camera to Begin Detections")
                    : Expanded(
                  child: Container(
                      child:
                      _objectModel.renderBoxesOnImage(_image!, objDetect)),
                ),

                 */


              ]
          )
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async{
          try {
            if(controller != null){ //check if contrller is not null
              if(controller!.value.isInitialized){ //check if controller is initialized
                controller?.setFlashMode(FlashMode.off);
                final XFile? _image_test = await controller!.takePicture(); //capture image
                image = await controller!.takePicture(); //capture image
                final interpreter = await tfl.Interpreter.fromAsset('yolov5n-fp16.tflite');

                print(interpreter);
                //interpreter.run(input, output);

                //scheduleTimeout(5 * 1000);
                setState(() {
                  //update UI
                  _image = File(_image_test!.path);
                });
              }
            }
          } catch (e) {
            print(e); //show error
          }
        },
        child: Icon(Icons.camera),
      ),

    );
  }
}