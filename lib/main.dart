import 'package:bus/BLoc/map_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

void main() {
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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final MapController controller = MapController();
  bool fixOnCenter = true;

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

  LatLng center;
  List<LatLng> peoplePoints;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (context) => MapBloc(),
      child: BlocBuilder<MapBloc, MapState>(
        builder: (context, MapState state) {
          peoplePoints = state.peopleLocations.values.toList();
          print(peoplePoints.length);
          if (state.myLocation.location != null) {
            print('location Updated');
            center = state.myLocation.location;
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
                    Switch(
                        value: state.onBus,
                        onChanged: (value) {
                          context.read<MapBloc>().changeUseStatus();
                        }),
                  ],
                )
              ],
            ),
            body: FlutterMap(
              options: MapOptions(
                center: LatLng(31.88212374450709, 54.369690043577506),
                zoom: 14.0,
                minZoom: 5,
                maxZoom: 18.4,
                onPositionChanged: (MapPosition position, bool hasGesture) {
                  if (hasGesture) fixOnCenter = false;
                },
                onLongPress: (tapPosition, LatLng point) {
                  print(point.latitude);
                  print(point.longitude);
                  context.read<MapBloc>().addMarker(point);
                },
              ),
              mapController: controller,
              layers: [
                TileLayerOptions(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayerOptions(
                  markers: [
                    if (center != null)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: center,
                        builder: (ctx) => Container(
                          child: Column(
                            children: [
                              Icon(
                                state.onBus
                                    ? Icons.directions_bus_rounded
                                    : Icons.location_on_rounded,
                                size: 30,
                                color: state.onBus
                                    ? Colors.deepOrange
                                    : Colors.blue,
                              ),
                              if (state.onBus)
                                Text(
                                  'Line Name',
                                  style: TextStyle(fontSize: 10),
                                )
                            ],
                          ),
                        ),
                      ),
                    for (LatLng position in peoplePoints)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: position,
                        builder: (ctx) => new Container(
                          child: new Icon(
                            Icons.person,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    for (LatLng position in state.markers)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: position,
                        builder: (ctx) => new Container(
                          child: new Icon(
                            Icons.location_on_rounded,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                  ],
                ),
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
                FloatingActionButton(
                    child: Icon(Icons.alt_route_rounded),
                    backgroundColor: Colors.red,
                    onPressed: () async {
                      context.read<MapBloc>().getRoute(state.markers);
                      context.read<MapBloc>().connectToServer();
                    }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: FloatingActionButton(
                      child: state.myLocation.location == null
                          ? CircularProgressIndicator(color: Colors.white)
                          : Icon(Icons.location_on),
                      backgroundColor: Colors.green,
                      onPressed: () async {
                        fixOnCenter = false;
                        LocationData position =
                            await context.read<MapBloc>().determinePosition();
                        await _animatedMapMove(
                            LatLng(position.latitude, position.longitude), 14);
                        // onCenter = true;
                      }),
                ),
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
      ),
    );
  }
}
