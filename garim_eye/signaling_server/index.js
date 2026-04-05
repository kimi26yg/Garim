const io = require("socket.io")(3000, {
  cors: {
    origin: "*",
  },
});

console.log("Signaling server running on port 3000");

io.on("connection", (socket) => {
  console.log("User connected:", socket.id);

  socket.on("join", (roomId) => {
    socket.join(roomId);
    console.log(`User ${socket.id} joined room: ${roomId}`);
    // Notify others in the room
    socket.to(roomId).emit("user-connected", socket.id);
  });

  socket.on("offer", (payload) => {
    // payload: { target: targetSocketId, sdp: ... } or just broadcast to room if 1:1
    // We'll assume room-based broadcasting for simplicity as per instructions
    const { roomId, sdp } = payload;
    console.log(`Offer from ${socket.id} to room ${roomId}`);
    socket.to(roomId).emit("offer", { sdp, sender: socket.id });
  });

  socket.on("answer", (payload) => {
    const { roomId, sdp, type } = payload;
    console.log(`Answer from ${socket.id} to room ${roomId}`);
    socket.to(roomId).emit("answer", { sdp, type, sender: socket.id });
  });

  socket.on("ice-candidate", (payload) => {
    const { roomId, candidate, sdpMid, sdpMLineIndex } = payload;
    console.log(`ICE Candidate from ${socket.id} to room ${roomId}`);
    socket.to(roomId).emit("ice-candidate", { candidate, sdpMid, sdpMLineIndex, sender: socket.id });
  });

  socket.on("disconnect", () => {
    console.log("User disconnected:", socket.id);
  });
});
