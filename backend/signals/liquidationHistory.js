import axios from "axios";

// Aave v2
async function aaveLiquidations(address) {
  const query = `
    {
      liquidationCalls(where: {user: "${address.toLowerCase()}"}) {
        id
      }
    }
  `;
  try {
    const res = await axios.post(
      "https://api.thegraph.com/subgraphs/name/aave/protocol-v2",
      { query }
    );
    return res.data.data.liquidationCalls.length;
  } catch {
    return 0;
  }
}

// Compound v2
async function compoundLiquidations(address) {
  const query = `
    {
      liquidations(where: {borrower: "${address.toLowerCase()}"}) {
        id
      }
    }
  `;
  try {
    const res = await axios.post(
      "https://api.thegraph.com/subgraphs/name/compound-finance/compound-v2",
      { query }
    );
    return res.data.data.liquidations.length;
  } catch {
    return 0;
  }
}

// Morpho Blue
async function morphoLiquidations(address) {
  const query = `
    query {
      liquidations(filter: { borrower: { equals: "${address.toLowerCase()}" } }) {
        id
      }
    }
  `;
  try {
    const res = await axios.post("https://blue-api.morpho.org/graphql", {
      query,
    });
    return res.data.data.liquidations.length;
  } catch {
    return 0;
  }
}

export async function liquidationHistory(address) {
  try {
    const aave = await aaveLiquidations(address);
    const comp = await compoundLiquidations(address);
    const morpho = await morphoLiquidations(address);

    const total = aave + comp + morpho;

    const points = total === 0 ? 10 : 0;

    return {
      name: "Never Liquidated",
      points,
      max: 10,
      timesLiquidated: total
    };
  } catch (err) {
    console.error("Liquidation error", err);
    return { name: "Never Liquidated", points: 0, max: 10 };
  }
}
