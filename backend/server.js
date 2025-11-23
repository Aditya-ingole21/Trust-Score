import express from "express";
import cors from "cors";
import { ethers } from "ethers";

const app = express();
app.use(cors());
app.use(express.json());

// Temporary dev signer (publicly known, only for testing)
const signerPrivateKey =
  "0x59c6995e998f97a5a0044976f07ddb3e8cf728b7fbc75b7d52b35b5e17739b80";

const signer = new ethers.Wallet(signerPrivateKey);

// Mock score endpoint
app.get("/api/score", async (req, res) => {
  const address = req.query.address;

  if (!address || !ethers.isAddress(address)) {
    return res.status(400).json({ error: "Invalid address" });
  }

  const trustScore = 85;
  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + 600;

  const payload = { address, trustScore, issuedAt, expiresAt };
  const signature = await signer.signMessage(JSON.stringify(payload));

  res.json({ ...payload, signature });
});

app.listen(5000, () => {
  console.log("Backend running at http://localhost:5000");
});
