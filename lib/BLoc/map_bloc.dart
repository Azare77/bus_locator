import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bus/Model/Functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MapState {
  LatLng myLocation;
  List<LatLng> route;
  List<LatLng> markers;

  MapState(this.myLocation, this.route, this.markers);
}

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc() : super(MapState(null, [], [])) {
    print('data');
    connectToServer();
    Timer.periodic(Duration(seconds: 10), (timer) {
      determinePosition();
    });
  }

  IO.Socket socket = IO.io('http://176.9.178.49:3000', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': true,
  });

  void connectToServer() {
    socket.on('connect', (_) {
      print('connect');
      socket.emit('user_connect', {"connectedId": 6});
    });
    socket.on('event', (data) {
      print(data);
      // Timer(Duration(seconds: 5),(){
      socket.emit('msg', data.toString());
      // });
    });
    socket.on('disconnect', (_) => print('disconnect'));
    socket.on('fromServer', (_) => print(_));
    socket.on('error', (_) => print(_));
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permantly denied, we cannot request permissions.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return Future.error(
            'Location permissions are denied (actual value: $permission).');
      }
    }
    Position myPosition = await Geolocator.getCurrentPosition();
    state..myLocation = LatLng(myPosition.latitude, myPosition.longitude);
    add(MapEvent.GetMyLocation);
    return myPosition;
  }

  void getRoute(List<LatLng> positions) async {
    List<LatLng> route = await getDirections(positions);
    state..route = route;
    state..markers = [];
    add(MapEvent.GetRoute);
  }

  void _getMyLocation() async {}

  void addMarker(LatLng position) {
    state..markers.add(position);
    add(MapEvent.addMarker);
  }

  @override
  Stream<MapState> mapEventToState(MapEvent event) async* {
    if (event == MapEvent.GetMyLocation) {
      yield MapState(state.myLocation, state.route, state.markers);
    } else if (event == MapEvent.GetRoute) {
      yield MapState(state.myLocation, state.route, state.markers);
    } else if (event == MapEvent.addMarker) {
      yield MapState(state.myLocation, state.route, state.markers);
    }
  }
}

enum MapEvent { GetMyLocation, GetRoute, addMarker }
