import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
Future<List<LatLng>> getDirections(List<LatLng> positions) async {
  try {
    String pos = '';
    for (LatLng latLng in positions)
      pos = pos + '${latLng.longitude},${latLng.latitude};';
    pos = pos.substring(0, pos.length - 2);
    print(
        "https://routing.openstreetmap.de/routed-car/route/v1/driving/$pos?overview=false&alternatives=true&steps=true");
    Response response = await Dio().get(
        "https://routing.openstreetmap.de/routed-car/route/v1/driving/$pos?overview=false&alternatives=true&steps=true");
    Map responseBody = response.data;
    List<LatLng> points = [];
    for (Map direction in responseBody['routes'][0]['legs']) {
      for (Map step in direction['steps']) {
        List<PointLatLng> point =
            PolylinePoints().decodePolyline(step['geometry']);
        for (PointLatLng location in point) {
          points.add(LatLng(location.latitude, location.longitude));
        }
      }
    }
    return points;
  } catch (e) {
    print(e);
    return [];
  }
}
