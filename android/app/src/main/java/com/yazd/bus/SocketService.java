package com.yazd.bus;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.location.Location;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;

import org.json.JSONObject;

import java.net.URISyntaxException;


import io.flutter.Log;
import io.socket.client.IO;
import io.socket.client.Socket;
import io.socket.emitter.Emitter;

public class SocketService extends Service {

    MyLocation.LocationResult locationResult = new MyLocation.LocationResult() {
        @Override
        public void gotLocation(Location location) {
            try {
//                Log.e("fatal", location.getLatitude() + "   " + location.getLongitude());
                JSONObject map = new JSONObject();
                map.put("lat", location.getLatitude());
                map.put("lng", location.getLongitude());
                if (!socket.connected() || !socket.isActive())
                    socket.connect();
                socket.emit("sendLocation", map);
            } catch (Exception ignored) {

            }
        }
    };
    MyLocation myLocation = new MyLocation();
    Handler handler;
    Socket socket;
    String id;

    @Override
    public void onCreate() {
        Log.e("fatal", "susses create");
        handler = new Handler();
        myLocation = new MyLocation();
        super.onCreate();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.e("fatal", "susses connect");
        Context context = this;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startMyOwnForeground();
            }
            socket = IO.socket("http://127.0.0.1:3000");
            socket.connect();
            myLocation.getLocation(context, locationResult);
            handler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    myLocation.getLocation(context, locationResult);
                    handler.postDelayed(this, 1000);
                }
            }, 5000);
        } catch (URISyntaxException e) {
            Log.e("fatal", e.getMessage() != null ? e.getMessage() : "connection error");
        }

        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        socket.emit("stopBroadcast");
        socket.disconnect();
        Log.e("fatal", "'susses disconnect'");
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    private void startMyOwnForeground() {
        String NOTIFICATION_CHANNEL_ID = "com.yazd.bus";
        String channelName = "My Background Service";
        NotificationChannel chan = new NotificationChannel(NOTIFICATION_CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_NONE);
        chan.setLightColor(Color.BLUE);
        chan.setLockscreenVisibility(Notification.VISIBILITY_PRIVATE);
        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        assert manager != null;
        manager.createNotificationChannel(chan);

        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID);
        Notification notification = notificationBuilder.setOngoing(true)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("App is running in background")
                .setPriority(NotificationManager.IMPORTANCE_MIN)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build();
        startForeground(2, notification);
    }
}
