import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bus/Model/Functions.dart';
import 'package:bus/Model/LocationModel.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MapState {
  LocationModel myLocation;
  Map<String, LatLng> peopleLocations;
  List<LatLng> route;
  List<LatLng> markers;
  bool onBus;

  MapState(this.myLocation, this.peopleLocations, this.route, this.markers,
      this.onBus);
}

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc() : super(MapState(LocationModel(null, null), {}, [], [], false)) {
    connectToServer();
    setupLocationService();
  }

  IO.Socket socket = IO.io('http://192.168.1.9:3000', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': true,
  });

  void connectToServer() {
    socket.connect();
    socket.on('connect', (_) {
      print('connect');
    });
    socket.on('getLocation', (data) {
      if (state.myLocation.id != data['user_id']) {
        state
          ..peopleLocations[data['user_id']] = LatLng(data['lat'], data['lng']);
        add(MapEvent.GetMyLocation);
      }
    });
    socket.on('get_id', (data) {
      state..myLocation.id = data.toString();
      add(MapEvent.GetMyLocation);
    });
    socket.on('userStopBroadcast', (data) {
      print(data);
      print(data['user_id'].runtimeType);
      state..peopleLocations.remove(data['user_id']);
      state.peopleLocations.forEach((key, value) {
        print(key);
      });
      add(MapEvent.GetMyLocation);
    });
    socket.on('disconnect', (_) => socket.connect());
    // socket.on('fromServer', (_) => print(_));
    socket.on('error', (_) => socket.connect());
  }

  Location _location;

  void setupLocationService() async {
    _location = Location();
    // await location.enableBackgroundMode(enable: true);
    await determinePosition();
    _location.onLocationChanged.listen((LocationData currentLocation) {
      if (socket.disconnected) connectToServer();
      if (state.onBus)
        socket.emit('sendLocation', {
          "lat": currentLocation.latitude,
          "lng": currentLocation.longitude
        });
      double latitudeDifference =
          currentLocation.latitude - state.myLocation.location.latitude;
      double longitudeDifference =
          currentLocation.longitude - state.myLocation.location.longitude;
      if (latitudeDifference.abs() > 0.0001 ||
          longitudeDifference.abs() > 0.0001) {
        state
          ..myLocation = LocationModel(state.myLocation.id,
              LatLng(currentLocation.latitude, currentLocation.longitude));
        add(MapEvent.GetMyLocation);
      }
    });
  }

  Future<LocationData> determinePosition() async {
    bool _serviceEnabled;
    LocationData _locationData;
    PermissionStatus _permissionGranted;
    state..myLocation.location = null;
    add(MapEvent.GetMyLocation);
    try {
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        print('get location');
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

  void getRoute(List<LatLng> positions) async {
    List<LatLng> route = await getDirections(positions);
    state..route = route;
    state..markers = [];
    add(MapEvent.GetRoute);
  }

  void addMarker(LatLng position) {
    state..markers.add(position);
    add(MapEvent.addMarker);
  }

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

  @override
  Stream<MapState> mapEventToState(MapEvent event) async* {
    yield MapState(state.myLocation, state.peopleLocations, state.route,
        state.markers, state.onBus);
  }
}

enum MapEvent { GetMyLocation, GetRoute, addMarker }
