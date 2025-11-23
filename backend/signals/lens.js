import axios from "axios";

export async function lensProfile(address) {
  try {
    const query = {
      query: `
        query {
          profiles(request: { where: { ownedBy: ["${address.toLowerCase()}"] } }) {
            items {
              id
              handle
            }
          }
        }
      `
    };

    const res = await axios.post(
      "https://api-v2.lens.dev/",
      query,
      { headers: { "Content-Type": "application/json" } }
    );

    const profiles = res.data?.data?.profiles?.items || [];
    const hasProfile = profiles.length > 0;

    return {
      name: "Lens Profile",
      points: hasProfile ? 4 : 0,
      max: 4,
      profiles
    };

  } catch (err) {
    console.error("Lens error:", err);
    return { name: "Lens Profile", points: 0, max: 4 };
  }
}
