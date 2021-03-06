import 'dart:async';
import 'dart:collection';

import 'package:bloc/bloc.dart';
import 'package:bus/Model/Functions.dart';
import 'package:bus/Model/LocationModel.dart';
import 'package:bus/Model/PeopleLocationModel.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';

class MapState {
  LocationModel myLocation;
  HashMap<String, PeopleLocationModel> peopleLocations;
  List<LatLng> route;
  List<LatLng> markers;
  bool onBus;
  double zoom;

  MapState(this.myLocation, this.peopleLocations, this.route, this.markers,
      this.onBus, this.zoom);
}

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc()
      : super(
            MapState(LocationModel(null, null), HashMap(), [], [], false, 14)) {
    connectToServer();
    setupLocationService();
    Timer.periodic(validDuration, (timer) => checkLocationsValidation());
  }

  static const platform = MethodChannel('com.yazd.bus/socket');
  Duration validDuration = const Duration(seconds: 5);
  bool onBackground = false;

  Future<void> connectToSocket() async {
    try {
      if (!state.onBus) return;
      socket.emit('stopBroadcast');
      socket.close();
      var res = await platform.invokeMethod('connectToSocket');
      onBackground = true;
      print(res);
    } on PlatformException catch (e) {
      onBackground = false;
      print("Failed to connect to socket : '${e.message}'.");
    }
  }

  Future<void> disconnectFromSocket() async {
    try {
      if (!state.onBus) return;
      onBackground = false;
      socket.open();
      connectToServer();
      var res = await platform.invokeMethod('disconnectFromSocket');
      print(res);
    } on PlatformException catch (e) {
      onBackground = false;
      print("Failed to disconnect to socket : '${e.message}'.");
    }
  }

  IO.Socket socket;

  //make connection to server
  Future<void> connectToServer() async {
    if (onBackground) return;
    socket = IO.io(
        'http://127.0.0.1:3000',
        OptionBuilder()
            .setTransports(['websocket']) // for Flutter or Dart VM
            .enableAutoConnect()
            .build());
    socket.on('connect', (_) {
      print('connect');
    });

    //update or create new people location
    socket.on('getLocation', (data) {
      print(data);
      if (state.myLocation.id != null &&
          state.myLocation.id != data['user_id']) {
        state
          ..peopleLocations[data['user_id']] = PeopleLocationModel(
              DateTime.now(), LatLng(data['lat'], data['lng']));
        add(MapEvent.GetMyLocation);
      }
    });

    // get this client id to don't consider itself as other users
    socket.on('get_id', (data) {
      state..myLocation.id = data.toString();
      add(MapEvent.GetMyLocation);
    });
    // when a user stop broadcast her/his location
    socket.on('userStopBroadcast', (data) {
      state..peopleLocations.remove(data['user_id']);
      add(MapEvent.GetPeopleLocation);
    });
    // socket.on('fromServer', (_) => print(_));

    //make suer that you are connect :)
    socket.onDisconnect((data) async {
      await connectToServer();
    });
    socket.onConnectError((data) async {
      await connectToServer();
    });
    socket.onConnectTimeout((data) async {
      await connectToServer();
    });
  }

// check if a location is expired the ttl is 5 seconds
  checkLocationsValidation() async {
    DateTime currentTime = DateTime.now();
    try {
      state.peopleLocations.forEach((key, value) {
        if (value.time.isBefore(currentTime.subtract(validDuration))) {
          print(key);
          state..peopleLocations.remove(key);
        }
      });
    } catch (e) {
      checkLocationsValidation();
    }
    add(MapEvent.GetPeopleLocation);
  }

  Location _location;

//call enable location service and set a listener to send user location
  void setupLocationService() async {
    _location = Location();
    await _location.enableBackgroundMode(enable: true);
    await determinePosition();
    _location.onLocationChanged.listen((LocationData currentLocation) {
      if (socket.disconnected) connectToServer();

      double latitudeDifference =
          currentLocation.latitude - state.myLocation.location.latitude;
      double longitudeDifference =
          currentLocation.longitude - state.myLocation.location.longitude;

      if (state.onBus)
        socket.emit('sendLocation', {
          "lat": currentLocation.latitude,
          "lng": currentLocation.longitude
        });

      //it sends when user move a distance
      if (latitudeDifference.abs() > 0.0001 ||
          longitudeDifference.abs() > 0.0001) {
        if (state.onBus)
          socket.emit('sendLocation', {
            "lat": currentLocation.latitude,
            "lng": currentLocation.longitude
          });
        state
          ..myLocation = LocationModel(state.myLocation.id,
              LatLng(currentLocation.latitude, currentLocation.longitude));
        add(MapEvent.GetMyLocation);
      }
    });
  }

  //enable location service and get user location
  Future<LocationData> determinePosition() async {
    bool _serviceEnabled;
    LocationData _locationData;
    PermissionStatus _permissionGranted;
    state..myLocation.location = null;
    add(MapEvent.GetMyLocation);
    try {
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          return null;
        }
      }
      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return null;
        }
      }
      _locationData = await _location.getLocation();
      state
        ..myLocation = LocationModel(state.myLocation.id,
            LatLng(_locationData.latitude, _locationData.longitude));
      add(MapEvent.GetMyLocation);
      return _locationData;
    } catch (e) {
      return await determinePosition();
    }
  }

  //routing method
  void getRoute(List<LatLng> positions) async {
    List<LatLng> route = await getDirections(positions);
    state..route = route;
    state..markers = [];
    add(MapEvent.GetRoute);
  }

  // add markers to navigate between them
  void addMarker(LatLng position) {
    state..markers.add(position);
    add(MapEvent.addMarker);
  }

  //start/stop broadcasting
  void changeUseStatus() {
    if (state.onBus)
      socket.emit('stopBroadcast');
    else
      socket.emit('sendLocation', {
        "lat": state.myLocation.location.latitude,
        "lng": state.myLocation.location.longitude
      });

    state..onBus = !state.onBus;
    add(MapEvent.addMarker);
  }

  //it will set icons size
  void changeZoom(double zoom) {
    state..zoom = zoom;
    add(MapEvent.ChangeZoom);
  }

  @override
  Stream<MapState> mapEventToState(MapEvent event) async* {
    yield MapState(state.myLocation, state.peopleLocations, state.route,
        state.markers, state.onBus, state.zoom);
  }
}

enum MapEvent {
  GetMyLocation,
  GetPeopleLocation,
  GetRoute,
  addMarker,
  ChangeZoom
}
