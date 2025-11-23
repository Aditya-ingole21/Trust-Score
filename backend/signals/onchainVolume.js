import axios from "axios";

// helper to get token price (USD)
async function getPrice(symbol) {
  try {
    const res = await axios.get(
      `https://api.coingecko.com/api/v3/simple/price?ids=${symbol}&vs_currencies=usd`
    );
    return res.data[symbol].usd;
  } catch (err) {
    console.error("Price error", symbol, err);
    return 0;
  }
}

export async function onchainVolume(address) {
  try {
    // 1. Get normal transactions (ETH transfers)
    const baseTxUrl =
      `https://api.basescan.org/api?module=account&action=txlist&address=${address}&sort=asc`;

    const res1 = await axios.get(baseTxUrl);
    const txs = res1.data.result || [];

    let totalUsd = 0;

    // get ETH price
    const ethPrice = await getPrice("ethereum");

    // sum ETH volume
    for (let tx of txs) {
      if (tx.value) {
        const ethValue = Number(tx.value) / 1e18;
        totalUsd += ethValue * ethPrice;
      }
    }

    // 2. Get ERC20 token transfers
    const tokenTxUrl =
      `https://api.basescan.org/api?module=account&action=tokentx&address=${address}&sort=asc`;

    const res2 = await axios.get(tokenTxUrl);
    const tokenTx = res2.data.result || [];

    for (let t of tokenTx) {
      const decimals = Number(t.tokenDecimal || 18);
      const amount = Number(t.value) / Math.pow(10, decimals);

      // Use token symbol from basescan → convert to coingecko ID later if needed
      // Now default: assume ERC20 ≈ stablecoin for simplicity
      totalUsd += amount;
    }

    // SCORING
    let points = 0;
    if (totalUsd > 500000) points = 8;
    else if (totalUsd > 250000) points = 6;
    else if (totalUsd > 50000) points = 4;
    else if (totalUsd > 5000) points = 2;

    return {
      name: "Onchain Volume",
      points,
      max: 8,
      rawVolumeUsd: Math.round(totalUsd)
    };

  } catch (err) {
    console.error("Onchain Volume error", err);
    return { name: "Onchain Volume", points: 0, max: 8 };
  }
}
