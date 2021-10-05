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
      home: MyHomePage(title: 'Flutter Demo Home Page'),
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
  Marker marker = Marker(
    width: 80.0,
    height: 80.0,
    point: new LatLng(31.89092216595675, 54.354271730811575),
    builder: (ctx) => new Container(
      child: new Icon(
        Icons.location_on_rounded,
        color: Colors.red,
      ),
    ),
  );

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (destLocation == null) return;
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (context) => MapBloc(),
      child: BlocBuilder<MapBloc, MapState>(
        builder: (context, MapState state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title)
            ),
            body: FlutterMap(
              options: new MapOptions(
                  center: LatLng(31.89092216595675, 54.354271730811575),
                  zoom: 13.0,
                  // controller: controller,
                  onLongPress: (LatLng pos) {
                    context.read<MapBloc>().addMarker(pos);
                  },
                  maxZoom: 18.4),
              mapController: controller,
              layers: [
                TileLayerOptions(
                    urlTemplate:
                    "https://api.mapbox.com/styles/v1/a-zare-developer/ckjpvqq7c55iq19qsu52oubkx/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiYS16YXJlLWRldmVsb3BlciIsImEiOiJja2pwcDR5dzEwYXFyMzNqeGFvMWh3dzNsIn0.B6fcEX4VQfQaK33rk04YLg",
                    // "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    additionalOptions: {
                      'accessToken':
                      'pk.eyJ1IjoiYS16YXJlLWRldmVsb3BlciIsImEiOiJja2pwcDR5dzEwYXFyMzNqeGFvMWh3dzNsIn0.B6fcEX4VQfQaK33rk04YLg',
                      'id': 'mapbox.mapbox-traffic-v1'
                    }),
                MarkerLayerOptions(
                  markers: [
                    if (state.myLocation != null)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: state.myLocation,
                        builder: (ctx) => new Container(
                          child: new Icon(
                            Icons.location_on_rounded,
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
                        color: Colors.purple),
                  ],
                )
              ],
            ),
            floatingActionButton: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                    child: Icon(Icons.location_on),
                    backgroundColor: Colors.red,
                    onPressed: () async {
                      // print('data');
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
                              18));
                    }),
              ],
            ),
          );
        },
      ),
    );
  }
}
