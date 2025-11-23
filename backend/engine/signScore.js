import { ethers } from "ethers";
import dotenv from "dotenv";
dotenv.config();

export function signScore(scoreData) {
  const privateKey = process.env.SIGNER_PRIVATE_KEY;

  if (!privateKey) {
    console.error("Missing SIGNER_PRIVATE_KEY");
    return "0x00";
  }

  const wallet = new ethers.Wallet(privateKey);
  const message = JSON.stringify(scoreData);

  return wallet.signMessage(message);
}
