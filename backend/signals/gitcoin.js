import axios from "axios";


export async function gitcoinPassport(address) {
  const apiKey = process.env.GITCOIN_API_KEY;

  if (!apiKey) {
    console.error("Missing GITCOIN_API_KEY");
    return { name: "Gitcoin Passport", points: 0, max: 15 };
  }

  try {
    const res = await axios.get(
      `https://api.scorer.gitcoin.co/registry/score/1/${address}`,
      {
        headers: {
          "X-API-Key": apiKey
        }
      }
    );

    const score = res.data.score || 0;
    const points = score >= 70 ? 15 : 0;

    return { name: "Gitcoin Passport", points, max: 15 };
  } catch (err) {
    console.error("Gitcoin error", err);
    return { name: "Gitcoin Passport", points: 0, max: 15 };
  }
}
