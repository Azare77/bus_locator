const { response } = require("express");
const express = require("express");
const socket = require("socket.io");

// App setup
const PORT = 3000;
const app = express();
const server = app.listen(PORT, function () {
    console.log(`Listening on port ${PORT}`);
    console.log(`http://127.0.0.1:${PORT}`);
});

app.get('/', function (req, res) {
    res.send('hello world')
})


// Socket setup
const io = socket(server);
const activeUsers = new Set();



io.on("connection", function (socket) {
    console.log("Made socket connection");
    activeUsers.add(socket.id);
    console.log(activeUsers.size);


    socket.emit('get_id', socket.id);

    socket.on("sendLocation", function (data) {
        data['user_id'] = socket.id;
        io.emit("getLocation", data);
    });

    socket.on("stopBroadcast", function () {
        response['user_id'] = socket.id;
        io.emit("userStopBroadcast", response);
    });

    socket.on("disconnect", () => {
        activeUsers.delete(socket.id);
        console.log(socket.id);
    });

});

