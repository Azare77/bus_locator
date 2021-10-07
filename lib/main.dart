import 'package:bus/BLoc/map_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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

  // Marker marker = Marker(
  //   width: 80.0,
  //   height: 80.0,
  //   point: new LatLng(31.89092216595675, 54.354271730811575),
  //   builder: (ctx) => new Container(
  //     child: new Icon(
  //       Icons.location_on_rounded,
  //       color: Colors.red,
  //     ),
  //   ),
  // );

  void _animatedMapMove(LatLng destLocation, double destZoom) {
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

  @override
  Widget build(BuildContext context) {
    LatLng center = LatLng(31.88212374450709, 54.369690043577506);
    return BlocProvider<MapBloc>(
      create: (context) => MapBloc(),
      child: BlocBuilder<MapBloc, MapState>(
        builder: (context, MapState state) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: FlutterMap(
              options: MapOptions(
                  center: center,
                  zoom: 14.0,
                  // controller: controller,
                  onTap: (tapPosition, point) {
                    print(controller.zoom);
                  },
                  onLongPress: (tapPosition, LatLng point) {
                    print(point.latitude);
                    print(point.longitude);
                    context.read<MapBloc>().addMarker(point);
                  },
                  minZoom: 10.5,
                  maxZoom: 18.4),
              mapController: controller,
              children: [
                Icon(
                  Icons.add,
                  color: Colors.red,
                )
              ],
              layers: [
                TileLayerOptions(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayerOptions(
                  markers: [
                    if (state.myLocation != null)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: state.myLocation,
                        builder: (ctx) => Container(
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 30,
                            color: Colors.blue,
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
                SizedBox(width: 5),
                FloatingActionButton(
                    child: Icon(Icons.location_on),
                    backgroundColor: Colors.green,
                    onPressed: () async {
                      context.read<MapBloc>().determinePosition().then(
                          (Position position) => _animatedMapMove(
                              LatLng(position.latitude, position.longitude),
                              14));
                    }),
                SizedBox(width: 5),
                FloatingActionButton(
                    child: Icon(Icons.compass_calibration_rounded),
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
