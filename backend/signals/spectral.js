import axios from "axios";


export async function spectralScore(address) {
  const apiKey = process.env.SPECTRAL_API_KEY;

  if (!apiKey) {
    console.error("Missing SPECTRAL_API_KEY");
    return { name: "Spectral Score", points: 0, max: 20 };
  }

  try {
    const res = await axios.get(
      `https://api.spectral.finance/api/v1/addresses/${address}/score`,
      { headers: { "X-API-Key": apiKey } }
    );

    const points = Math.min(20, Math.floor(res.data.score / 5));

    return { name: "Spectral Score", points, max: 20 };
  } catch (err) {
    console.error("Spectral error", err);
    return { name: "Spectral Score", points: 0, max: 20 };
  }
}
