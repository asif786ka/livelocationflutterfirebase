import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:livelocationfirebasefirestore/mymap.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final loc.Location location = loc.Location();
  StreamSubscription<Position>? _locationSubscription;
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    //_determinePosition();
    location.changeSettings(interval: 300, accuracy: loc.LocationAccuracy.low);
    location.enableBackgroundMode(enable: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('live location tracker'),
      ),
      body: Column(
        children: [
          TextButton(
              onPressed: () {
                _determinePosition();
              },
              child: Text('add my location')),
          TextButton(
              onPressed: () {
                _listenLocation();
              },
              child: Text('enable live location')),
          TextButton(
              onPressed: () {
                _stopListening();
              },
              child: Text('stop live location')),
          Text(
              "LAT: ${currentPosition?.latitude}, LNG: ${currentPosition?.longitude}"
          ),
          Expanded(
              child: StreamBuilder(
                stream:
                FirebaseFirestore.instance.collection('location').snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  return ListView.builder(
                      itemCount: snapshot.data?.docs.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title:
                          Text(snapshot.data!.docs[index]['name'].toString()),
                          subtitle: Row(
                            children: [
                              Text(snapshot.data!.docs[index]['latitude']
                                  .toString()),
                              const SizedBox(
                                width: 20,
                              ),
                              Text(snapshot.data!.docs[index]['longitude']
                                  .toString()),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.directions),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      MyMap(snapshot.data!.docs[index].id)));
                            },
                          ),
                        );
                      });
                },
              )),
        ],
      ),
    );
  }




    /// Determine the current position of the device.
    ///
    /// When the location services are not enabled or permissions
    /// are denied the `Future` will return an error.
      _determinePosition() async {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled don't continue
        // accessing the position and request users of the
        // App to enable the location services.
        return Future.error('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied, next time you could try
          // requesting permissions again (this is also where
          // Android's shouldShowRequestPermissionRationale
          // returned true. According to Android guidelines
          // your App should show an explanatory UI now.
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      // When we reach here, permissions are granted and we can
      // continue accessing the position of the device.

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(()  {
        currentPosition = position;
      });
    }


  _getCurrentLocation() async {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await FirebaseFirestore.instance.collection('location').doc('user1').set({
        'latitude': currentPosition?.latitude,
        'longitude': currentPosition?.longitude,
        'name': 'john'
      }, SetOptions(merge: true));
  }

  _getLocation() async {
    try {

      bool _serviceEnabled;

      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          return;
        }
      }

      final loc.LocationData _locationResult = await location.getLocation();
      print('stranddlocation${_locationResult.latitude}');
      print('stranddlongitude${_locationResult.longitude}');
     /* await FirebaseFirestore.instance.collection('location').doc('user1').set({
        'latitude': _locationResult.latitude,
        'longitude': _locationResult.longitude,
        'name': 'john'
      }, SetOptions(merge: true));*/
    } catch (e) {
      print(e);
    }
  }

  Future<void> _listenLocation() async {
    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 10),
          //(Optional) Set foreground notification config to keep the app alive
          //when going to the background
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText:
            "Example app will continue to receive your location even when you aren't using it",
            notificationTitle: "Running in Background",
            enableWakeLock: true,
          )
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 100,
        pauseLocationUpdatesAutomatically: true,
        // Only set to true if our app will be started up in the background.
        showBackgroundLocationIndicator: false,
      );
    }

    _locationSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position? position) async {
          print(position == null ? 'Unknown' : '${position.latitude.toString()}, ${position.longitude.toString()}');
          await FirebaseFirestore.instance.collection('location').doc('user1').set({
            'latitude': position?.latitude,
            'longitude': position?.longitude,
            'name': 'john'
          }, SetOptions(merge: true));
        });

  }

  _stopListening() {
    _locationSubscription?.cancel();
    setState(() {
      _locationSubscription = null;
    });
  }

  _requestPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      print('done');
      _getCurrentLocation();
    } else if (status.isDenied) {
      _requestPermission();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }
}
