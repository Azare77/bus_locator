import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bus/Model/Functions.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MapState {
  LatLng myLocation;
  List<LatLng> route;
  List<LatLng> markers;
  bool onBus;

  MapState(this.myLocation, this.route, this.markers, this.onBus);
}

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc() : super(MapState(null, [], [], false)) {
    connectToServer();
    setupLocationService();
  }

  // IO.Socket socket = IO.io('http://server', <String, dynamic>{
  //   'transports': ['websocket'],
  //   'autoConnect': true,
  // });

  void connectToServer() {
    // socket.on('connect', (_) {
    //   print('connect');
    //   socket.emit('user_connect', {"connectedId": 6});
    // });
    // socket.on('event', (data) {
    //   print(data);
    //   // Timer(Duration(seconds: 5),(){
    //   socket.emit('msg', data.toString());
    //   // });
    // });
    // socket.on('disconnect', (_) => print('disconnect'));
    // socket.on('fromServer', (_) => print(_));
    // socket.on('error', (_) => print(_));
  }

  Location location;

  void setupLocationService() async {
    location = Location();
    await location.enableBackgroundMode(enable: true);
    await determinePosition();
    location.onLocationChanged.listen((LocationData currentLocation) {
      double latitudeDifference =
          currentLocation.latitude - state.myLocation.latitude;
      double longitudeDifference =
          currentLocation.longitude - state.myLocation.longitude;
      if (latitudeDifference.abs() > 0.0001 ||
          longitudeDifference.abs() > 0.0001) {
        state
          ..myLocation =
              LatLng(currentLocation.latitude, currentLocation.longitude);
        add(MapEvent.GetMyLocation);
      }
    });
  }

  Future<LocationData> determinePosition() async {
    bool _serviceEnabled;
    LocationData _locationData;
    PermissionStatus _permissionGranted;

    try{
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        print('get location');
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          return null;
        }
      }
      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return null;
        }
      }
      _locationData = await location.getLocation();
      state..myLocation = LatLng(_locationData.latitude, _locationData.longitude);
      add(MapEvent.GetMyLocation);
      return _locationData;
    } catch(e){
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
    state..onBus = !state.onBus;
    add(MapEvent.addMarker);
  }

  @override
  Stream<MapState> mapEventToState(MapEvent event) async* {
    yield MapState(state.myLocation, state.route, state.markers, state.onBus);
  }
}

enum MapEvent { GetMyLocation, GetRoute, addMarker }
