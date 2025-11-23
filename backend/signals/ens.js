import axios from "axios";

export async function ensName(address) {
  try {
    const query = `
      {
        domains(where: {owner: "${address.toLowerCase()}"}) {
          id
          name
        }
      }
    `;

    const res = await axios.post(
      "https://api.thegraph.com/subgraphs/name/ensdomains/ens",
      { query }
    );

    const domains = res.data?.data?.domains || [];

    const hasENS = domains.length > 0;
    const points = hasENS ? 4 : 0;

    return {
      name: "ENS Name Owned",
      points,
      max: 4,
      names: domains.map(d => d.name)
    };

  } catch (err) {
    console.error("ENS error", err);
    return { name: "ENS Name Owned", points: 0, max: 4 };
  }
}
