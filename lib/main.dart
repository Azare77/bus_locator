import 'dart:io';

import 'package:bus/BLoc/map_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import 'Model/PeopleLocationModel.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = new MyHttpOverrides();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Bus Locator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  MapBloc bloc;

  final MapController controller = MapController();

  //if this var be true then camera will follow user location
  bool fixOnCenter = true;

  //user location
  LatLng myLocation;

  // this list have all other users location who share his/her location
  List<PeopleLocationModel> peopleLocations;

  @override
  initState() {
    bloc = MapBloc();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  dispose() {
    bloc.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('resumed');
      bloc.disconnectFromSocket();
    }
    if (state == AppLifecycleState.paused) {
      print('paused');
      bloc.connectToSocket();
    }
  }

  @override
  Widget build(BuildContext context) {
    //get size of screen
    Size size = MediaQuery.of(context).size;

    return BlocBuilder(
      bloc: bloc,
      // this builder calls when screen have a new event and needs to update
      builder: (context, MapState state) {
        //get newest user locations
        peopleLocations = state.peopleLocations.values.toList();
        if (state.myLocation.location != null) {
          myLocation = state.myLocation.location;
          if (fixOnCenter)
            _animatedMapMove(state.myLocation.location, controller.zoom);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              Row(
                children: [
                  Text('on Bus ?'),
                  //if this switch is on then your location is broadcasting
                  Switch(
                      value: state.onBus,
                      onChanged: (value) {
                        bloc.changeUseStatus();
                      }),
                ],
              )
            ],
          ),
          body: FlutterMap(
            options: MapOptions(
              //initial center location (it only use in first build)
              center: LatLng(31.88276335597011, 54.36766399046463),

              //these options will limit map area

              // nePanBoundary: LatLng(31.939580199898106, 54.38910940217473),
              // north-east last location witch user can't go any more

              // swPanBoundary: LatLng(31.832241219879364, 54.29659354468416),
              // south-west last location witch user can't go any more

              //initial zoom
              zoom: 14.0,
              // minZoom: 10.5,
              maxZoom: 18.4,
              screenSize: size,
              //to control icon size and camera follow option
              onPositionChanged: (MapPosition position, bool hasGesture) {
                //if user change camera manually so camera don't follow user any more
                if (hasGesture) fixOnCenter = false;

                // update icon sizes
                double zoom = double.parse(controller.zoom.toStringAsFixed(1));
                if (zoom != state.zoom) bloc.changeZoom(zoom);
              },

              //add some markers to navigate and route between them
              onLongPress: (tapPosition, LatLng point) {
                print(point.latitude);
                print(point.longitude);
                bloc.addMarker(point);
              },
            ),
            mapController: controller,
            layers: [
              //map skin
              TileLayerOptions(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),

              MarkerLayerOptions(
                markers: [
                  //show user loaction
                  if (myLocation != null)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: myLocation,
                      rotate: true,
                      builder: (ctx) => Icon(
                        state.onBus
                            ? Icons.directions_bus_rounded
                            : Icons.location_on_rounded,
                        size: state.zoom < 11 ? 10 : state.zoom * 2,
                        color:
                            state.onBus ? Colors.deepOrangeAccent : Colors.blue,
                      ),
                    ),

                  //show people location
                  for (PeopleLocationModel position in peopleLocations)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: position.location,
                      rotate: true,
                      builder: (ctx) => Icon(
                        Icons.directions_bus_rounded,
                        size: state.zoom < 11 ? 10 : state.zoom * 2,
                        color: Colors.deepOrangeAccent,
                      ),
                    ),

                  //show navigates markers witch user want to pass
                  for (LatLng position in state.markers)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: position,
                      rotate: true,
                      builder: (ctx) => Icon(
                        Icons.location_on_rounded,
                        color: Colors.purple,
                      ),
                    ),
                ],
              ),

              //show route between purple markers
              PolylineLayerOptions(
                polylineCulling: true,
                polylines: [
                  Polyline(
                      points: state.route,
                      strokeWidth: 4.0,
                      color: Colors.green),
                ],
              )
            ],
          ),
          floatingActionButton: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              //make routing operations and show on map
              FloatingActionButton(
                  child: Icon(Icons.alt_route_rounded),
                  backgroundColor: Colors.red,
                  onPressed: () async {
                    bloc.getRoute(state.markers);
                    bloc.connectToServer();
                  }),

              //force to get user location and make camera to follow user
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: FloatingActionButton(
                    child: state.myLocation.location == null
                        ? CircularProgressIndicator(color: Colors.white)
                        : Icon(Icons.location_on),
                    backgroundColor: Colors.green,
                    onPressed: () async {
                      fixOnCenter = false;
                      LocationData position = await bloc.determinePosition();
                      await _animatedMapMove(
                          LatLng(position.latitude, position.longitude), 14);
                      // onCenter = true;
                    }),
              ),

              //rotate map to 0 degrees
              FloatingActionButton(
                  child: Icon(Icons.arrow_upward_rounded),
                  backgroundColor: Colors.green,
                  onPressed: () async {
                    _animatedMapRotation(0);
                  }),
            ],
          ),
        );
      },
    );
  }

  //animation change camera location and zoom
  Future<void> _animatedMapMove(LatLng destLocation, double destZoom) async {
    if (destLocation == null) return;
    if (destZoom < controller.zoom) destZoom = controller.zoom;
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final _latTween = Tween<double>(
        begin: this.controller.center.latitude, end: destLocation.latitude);
    final _lngTween = Tween<double>(
        begin: this.controller.center.longitude, end: destLocation.longitude);
    final _zoomTween =
        Tween<double>(begin: this.controller.zoom, end: destZoom);
    // Create a animation controller that has a duration and a TickerProvider.
    var animationController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);
    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation = CurvedAnimation(
        parent: animationController, curve: Curves.fastOutSlowIn);

    animationController.addListener(() {
      this.controller.move(
          LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation)),
          _zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animationController.dispose();
        fixOnCenter = true;
      } else if (status == AnimationStatus.dismissed) {
        animationController.dispose();
      }
    });
    animationController.forward();
  }

  //animation to rotate map
  void _animatedMapRotation(double destRotation) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final _rotationTween =
        Tween<double>(begin: this.controller.rotation, end: destRotation);
    // Create a animation controller that has a duration and a TickerProvider.
    var animationController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);
    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation = CurvedAnimation(
        parent: animationController, curve: Curves.fastOutSlowIn);

    animationController.addListener(() {
      this.controller.rotate(_rotationTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animationController.dispose();
      } else if (status == AnimationStatus.dismissed) {
        animationController.dispose();
      }
    });

    animationController.forward();
  }
}
