import axios from "axios";

export async function walletAge(address) {
  try {
    const url = `https://api.basescan.org/api?module=account&action=txlist&address=${address}&sort=asc`;

    const res = await axios.get(url);

    let txs = res.data.result;

    // No transactions → age = 0
    if (!txs || !Array.isArray(txs) || txs.length === 0) {
      return { name: "Wallet Age", points: 0, max: 12 };
    }

    // Make sure timestamp exists
    if (!txs[0].timeStamp) {
      return { name: "Wallet Age", points: 0, max: 12 };
    }

    const firstTxTimestamp = Number(txs[0].timeStamp) * 1000;

    if (isNaN(firstTxTimestamp) || firstTxTimestamp <= 0) {
      return { name: "Wallet Age", points: 0, max: 12 };
    }

    const now = Date.now();
    const diffMs = now - firstTxTimestamp;

    const ageYears = diffMs / (1000 * 60 * 60 * 24 * 365);

    // Scoring
    let points = Math.floor(ageYears * 4);
    if (ageYears >= 3) points = 12;
    if (points < 0) points = 0;
    if (points > 12) points = 12;

    return {
      name: "Wallet Age",
      points,
      max: 12
    };

  } catch (err) {
    console.error("Wallet Age error", err);
    return { name: "Wallet Age", points: 0, max: 12 };
  }
}
