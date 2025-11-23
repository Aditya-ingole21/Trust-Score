export async function twitterFollowers(profile) {
  if (!profile || !profile.public_metrics) {
    return { name: "Twitter Followers", points: 0, max: 8 };
  }

  const f = profile.public_metrics.followers_count;

  let points = 0;
  if (f >= 10000) points = 8;
  else if (f >= 5000) points = 6;
  else if (f >= 1000) points = 3;
  else points = 0;

  return {
    name: "Twitter Followers",
    points,
    max: 8,
    followers: f
  };
}
