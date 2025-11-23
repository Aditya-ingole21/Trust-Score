export async function twitterAgeVerified(profile) {
  if (!profile) {
    return { name: "Twitter Age + Verification", points: 0, max: 5 };
  }

  const createdAt = new Date(profile.created_at);
  const years = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24 * 365);

  const verified = profile.verified;

  let points = 0;
  if (years >= 5 && verified) points = 5;

  return {
    name: "Twitter Age & Verification",
    points,
    max: 5,
    yearsOld: years.toFixed(2),
    verified
  };
}
