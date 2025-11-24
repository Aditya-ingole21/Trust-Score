import axios from "axios";
import qs from "qs";
import "dotenv/config";

const {
  TWITTER_CLIENT_ID,
  TWITTER_CLIENT_SECRET,
  TWITTER_REDIRECT_URI
} = process.env;

// Step 1 — Redirect user to Twitter
export function generateTwitterAuthURL() {
  const params = qs.stringify({
    response_type: "code",
    client_id: TWITTER_CLIENT_ID,
    redirect_uri: TWITTER_REDIRECT_URI,
    scope: "tweet.read users.read follows.read offline.access",
    state: "trustscore",
    code_challenge: "challenge",
    code_challenge_method: "plain",
  });
  return `https://twitter.com/i/oauth2/authorize?${params}`;
}

// Step 2 — Exchange code for access token
export async function getTwitterToken(code) {
  const data = qs.stringify({
    grant_type: "authorization_code",
    client_id: TWITTER_CLIENT_ID,
    redirect_uri: TWITTER_REDIRECT_URI,
    code_verifier: "challenge",
    code,
  });

  const res = await axios.post(
    "https://api.twitter.com/2/oauth2/token",
    data,
    {
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization:
          "Basic " +
          Buffer.from(
            TWITTER_CLIENT_ID + ":" + TWITTER_CLIENT_SECRET
          ).toString("base64"),
      },
    }
  );
  return res.data.access_token;
}

// Step 3 — Get follower count
export async function getTwitterProfile(token) {
  const res = await axios.get(
    "https://api.twitter.com/2/users/me?user.fields=public_metrics,created_at,verified",
    {
      headers: { Authorization: `Bearer ${token}` },
    }
  );
  return res.data.data;
}
