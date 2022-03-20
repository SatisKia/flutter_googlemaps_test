import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State createState() => _MyHomePageState();
}

class _MyHomePageState extends State {
  double contentWidth  = 0.0;
  double contentHeight = 0.0;

  String _latitude = '35.681236';
  String _longitude = '139.767125';
  TextEditingController latitudeController = TextEditingController();
  TextEditingController longitudeController = TextEditingController();

  double _zoom = 13.0;
  double? _north;
  double? _east;
  double? _south;
  double? _west;
  final Completer<GoogleMapController> _googleMapController = Completer();

  Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future setCameraPosition(double latitude, double longitude) async {
    GoogleMapController controller = await _googleMapController.future;
    double zoom = await controller.getZoomLevel();
    CameraPosition _pos = CameraPosition(
      target: LatLng(latitude, longitude),
      zoom: zoom,
    );
    controller.animateCamera(
      CameraUpdate.newCameraPosition(_pos),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      // テキストフィールドの更新
      latitudeController.text = _latitude.toString();
      longitudeController.text = _longitude.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    contentWidth  = MediaQuery.of( context ).size.width;
    contentHeight = MediaQuery.of( context ).size.height - MediaQuery.of( context ).padding.top - MediaQuery.of( context ).padding.bottom;

    CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(double.parse(_latitude), double.parse(_longitude)),
      zoom: _zoom,
    );
    Widget googleMap = GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: initialCameraPosition,
      onMapCreated: (GoogleMapController controller) {
        _googleMapController.complete(controller);
      },
      onCameraMove: (CameraPosition position) {
        setState(() {
          _zoom = position.zoom;
        });

        // テキストフィールドの更新
        latitudeController.text = position.target.latitude.toString();
        longitudeController.text = position.target.longitude.toString();
      },
      onCameraIdle: () async {
        GoogleMapController controller = await _googleMapController.future;
        double zoom = await controller.getZoomLevel();
        LatLngBounds bounds = await controller.getVisibleRegion();

        setState(() {
          _zoom = zoom;
          _north = bounds.northeast.latitude;
          _east = bounds.northeast.longitude;
          _south = bounds.southwest.latitude;
          _west = bounds.southwest.longitude;
        });

        // テキストフィールドの更新
        double latitude = (_north! + _south!) / 2;
        double longitude = (_east! + _west!) / 2;
        latitudeController.text = latitude.toString();
        longitudeController.text = longitude.toString();
      },
    );

    return Scaffold(
      appBar: AppBar(
          toolbarHeight: 0
      ),
      body: SingleChildScrollView(
        child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('latitude', style: TextStyle(fontSize: 20)),
          MyTextField(
              controller: latitudeController,
              onChanged: (value) {
                _latitude = value;

                // Googleマップウィジェットの更新
                setCameraPosition(double.parse(_latitude), double.parse(_longitude));
              }
          ),
          Text('longitude', style: TextStyle(fontSize: 20)),
          MyTextField(
              controller: longitudeController,
              onChanged: (value) {
                _longitude = value;

                // Googleマップウィジェットの更新
                setCameraPosition(double.parse(_latitude), double.parse(_longitude));
              }
          ),
          Row( children: [
            ElevatedButton(
              child: const Text('getCurrentPosition'),
              onPressed: () async {
                if( await requestLocationPermission() ){
                  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                  _latitude = position.latitude.toString(); // 緯度
                  _longitude = position.longitude.toString(); // 経度

                  // テキストフィールドの更新
                  latitudeController.text = _latitude;
                  longitudeController.text = _longitude;

                  // Googleマップウィジェットの更新
                  setCameraPosition(position.latitude, position.longitude);
                }
              },
            ),
            SizedBox(width: 10),
            ElevatedButton(
              child: const Text('launch'),
              onPressed: () async {
                String mapsUrl = 'https://www.google.com/maps/search/?api=1';
                double latitude = double.parse(_latitude);
                double longitude = double.parse(_longitude);
                launch('$mapsUrl&query=$latitude,$longitude', forceSafariVC: false);
              },
            ),
          ] ),
          SizedBox(
            width: contentWidth,
            height: contentWidth,
            child: googleMap,
          ),
          Text('zoom: $_zoom'),
          Visibility(
            visible: (_north != null),
            child: Text('latitude: $_north~$_south'),
          ),
          Visibility(
            visible: (_east != null),
            child: Text('longitude: $_east~$_west'),
          ),
        ] ),
      ),
    );
  }
}

class MyTextField extends TextField {
  MyTextField({required TextEditingController controller, required void Function(String) onChanged, Key? key}) : super(key: key,
    controller: controller,
    decoration: InputDecoration(
      border: const OutlineInputBorder(),
      contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
    ),
    autocorrect: false,
    keyboardType: TextInputType.text,
    onChanged: onChanged,
  );
}
