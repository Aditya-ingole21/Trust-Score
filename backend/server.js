import express from "express";
import cors from "cors";
import { ethers } from "ethers";
import { onchainVolume } from "./signals/onchainVolume.js";
import "dotenv/config";

const { SIGNER_PRIVATE_KEY } = process.env;
const signerPrivateKey = SIGNER_PRIVATE_KEY;


const app = express();
app.use(cors());
app.use(express.json());

// Temporary dev signer (publicly known, only for testing)

const signer = new ethers.Wallet(signerPrivateKey);

// Mock score endpoint
// app.get("/api/score", async (req, res) => {
//   const address = req.query.address;

//   if (!address || !ethers.isAddress(address)) {
//     return res.status(400).json({ error: "Invalid address" });
//   }

//   const trustScore = 85;
//   const issuedAt = Math.floor(Date.now() / 1000);
//   const expiresAt = issuedAt + 600;

//   const payload = { address, trustScore, issuedAt, expiresAt };
//   const signature = await signer.signMessage(JSON.stringify(payload));

//   res.json({ ...payload, signature });
// });


import { liquidationHistory } from "./signals/liquidationHistory.js";

app.get("/api/test-liquidations", async (req, res) => {
  const result = await liquidationHistory(req.query.address);
  res.json(result);
});

import { gitcoinPassport } from "./signals/gitcoin.js";

app.get("/api/test-gitcoin", async (req, res) => {
  const address = req.query.address;
  const result = await gitcoinPassport(address);
  res.json(result);
});

import { spectralScore } from "./signals/spectral.js";

app.get("/api/test-spectral", async (req, res) => {
  const result = await spectralScore(req.query.address);
  res.json(result);
});

import { repaymentHistory } from "./signals/repaymentHistory.js";

app.get("/api/test-repay", async (req, res) => {
  const address = req.query.address;
  const result = await repaymentHistory(address);
  res.json(result);
});





app.get("/api/test-volume", async (req, res) => {
  const address = req.query.address;
  const result = await onchainVolume(address);
  res.json(result);
});
import { ensName } from "./signals/ens.js";

app.get("/api/test-ens", async (req, res) => {
  const result = await ensName(req.query.address);
  res.json(result);
});
import { lensProfile } from "./signals/lens.js";

app.get("/api/test-lens", async (req, res) => {
  const result = await lensProfile(req.query.address);
  res.json(result);
});

import { discordRoles } from "./signals/discord.js";

app.get("/api/test-discord", (req, res) => {
  const fakeProfile = {
    username: "test",
    roles: ["Developer DAO", "Random"]
  };
  res.json(discordRoles(fakeProfile));
});





import { calculateTrustScore } from "./engine/calculateTrustScore.js";
import { signScore } from "./engine/signScore.js";

app.get("/api/score", async (req, res) => {
  const { address } = req.query;

  try {
    // Twitter & Discord not implemented yet → pass null
    const result = await calculateTrustScore(address, null, null);

    const signature = await signScore(result);

    res.json({
      address,
      trustScore: result.trustScore,
      breakdown: result.breakdown,
      signature
    });

  } catch (err) {
    console.error("Score error", err);
    res.status(500).json({ error: "Failed to calculate score" });
  }
});










app.listen(5000, () => {
  console.log("Backend running at http://localhost:5000");
});
