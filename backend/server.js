const express = require("express");
const { Client } = require("node-osc");
const cors = require("cors");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3000;
const RESOLUME_IP = process.env.RESOLUME_IP || "192.168.100.9"; // Ganti sesuai PC Resolume
const RESOLUME_PORT = 7000;

const oscClient = new Client(RESOLUME_IP, RESOLUME_PORT);

app.use(cors());
app.use(express.json());

// Endpoint untuk mengontrol Resolume
app.post("/play", (req, res) => {
  const { layer, clip } = req.body;
  if (!layer || !clip) {
    return res.status(400).json({ error: "Layer dan Clip harus diisi" });
  }

  const oscMessage = `/composition/layers/${layer}/clips/${clip}/connect`;
  oscClient.send(oscMessage, () => {
    console.log(`OSC Sent: ${oscMessage}`);
    res.json({ success: true, message: `Playing Layer ${layer} Clip ${clip}` });
  });
});

app.listen(PORT, () => {
  console.log(`✅ Server berjalan di http://localhost:${PORT}`);
});
