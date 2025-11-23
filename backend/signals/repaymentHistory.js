import axios from "axios";

async function fetchAaveRepayments(address) {
  const query = `
    {
      repays(where: {user: "${address.toLowerCase()}"}) {
        id
      }
    }
  `;

  try {
    const res = await axios.post(
      "https://api.thegraph.com/subgraphs/name/aave/protocol-v2",
      { query }
    );
    return res.data.data.repays.length;
  } catch {
    return 0;
  }
}

async function fetchCompoundRepayments(address) {
  const query = `
    {
      repays(where: {payer: "${address.toLowerCase()}"}) {
        id
      }
    }
  `;

  try {
    const res = await axios.post(
      "https://api.thegraph.com/subgraphs/name/compound-finance/compound-v2",
      { query }
    );
    return res.data.data.repays.length;
  } catch {
    return 0;
  }
}

async function fetchMorphoRepayments(address) {
  const query = `
    query {
      repayments(filter: { borrower: { equals: "${address.toLowerCase()}" } }) {
        id
      }
    }
  `;

  try {
    const res = await axios.post("https://blue-api.morpho.org/graphql", {
      query,
    });
    return res.data.data.repayments.length;
  } catch {
    return 0;
  }
}

export async function repaymentHistory(address) {
  try {
    const aave = await fetchAaveRepayments(address);
    const comp = await fetchCompoundRepayments(address);
    const morpho = await fetchMorphoRepayments(address);

    const total = aave + comp + morpho;

    let points = 0;
    if (total >= 20) points = 20;
    else if (total >= 10) points = 16;
    else if (total >= 5) points = 12;
    else if (total >= 2) points = 8;
    else if (total >= 1) points = 4;

    return {
      name: "Loans Repaid",
      points,
      max: 20,
      totalRepayments: total,
    };
  } catch {
    return { name: "Loans Repaid", points: 0, max: 20 };
  }
}
