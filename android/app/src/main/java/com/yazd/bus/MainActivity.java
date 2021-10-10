package com.yazd.bus;

import android.content.Intent;

import androidx.annotation.NonNull;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.yazd.bus/socket";
    private Intent
            servIntent;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("connectToSocket")) {
                                int batteryLevel = startSocketService();
                                if (batteryLevel != -1) {
                                    result.success(batteryLevel);
                                } else {
                                    result.error("UNAVAILABLE", "socket connection error.", null);
                                }
                            } else if (call.method.equals("disconnectFromSocket")) {
                                int batteryLevel = disconnectFromSocket();
                                if (batteryLevel != -1) {
                                    result.success(batteryLevel);
                                } else {
                                    result.error("UNAVAILABLE", "socket connection error.", null);
                                }
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }

    private int startSocketService() {
        servIntent = new Intent(this, SocketService.class);
        startService(servIntent);
        return 69;
    }

    private int disconnectFromSocket() {
        stopService(servIntent);
        return 85;
    }
}
