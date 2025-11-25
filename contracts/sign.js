import { ethers } from "ethers";

const PRIVATE_KEY = "0x5eb5539b43913fe06afc3f6a4acc5650543bd4b013cfca9ad560c082857503a0";
const wallet = new ethers.Wallet(PRIVATE_KEY);

const user = "0x42105ae08079B1F4896d49041B335Ad11fb1e2e7";
const score = 90;

const hash = ethers.keccak256(
    ethers.solidityPacked(["address", "uint256"], [user, score])
);

// MUST SIGN THE ETH HASH
const ethHash = ethers.hashMessage(ethers.getBytes(hash));

const signature = await wallet.signMessage(ethers.getBytes(hash));

console.log("Signature:", signature);
