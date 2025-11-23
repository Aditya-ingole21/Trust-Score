import { walletAge } from "../signals/walletAge.js";
import { onchainVolume } from "../signals/onchainVolume.js";
import { repaymentHistory } from "../signals/repaymentHistory.js";
import { liquidationHistory } from "../signals/liquidationHistory.js";
import { gitcoinPassport } from "../signals/gitcoin.js";
import { spectralScore } from "../signals/spectral.js";
import { ensName } from "../signals/ens.js";
import { lensProfile } from "../signals/lens.js";
import { twitterFollowers } from "../signals/twitter.js";
import { twitterAgeVerified } from "../signals/twitterAge.js";
import { discordRoles } from "../signals/discord.js";

// For now, Twitter and Discord data will be null (added later in OAuth)
export async function calculateTrustScore(address, twitter = null, discord = null) {
  const results = [];

  // 1. Wallet age
  results.push(await walletAge(address));

  // 2. Onchain volume
  results.push(await onchainVolume(address));

  // 3. Loans repaid
  results.push(await repaymentHistory(address));

  // 4. Never liquidated
  results.push(await liquidationHistory(address));

  // 5. Gitcoin
  results.push(await gitcoinPassport(address));

  // 6. Spectral score
  results.push(await spectralScore(address));

  // 7. ENS
  results.push(await ensName(address));

  // 8. Lens
  results.push(await lensProfile(address));

  // 9. Twitter followers (0 now)
  results.push(await twitterFollowers(twitter));

  // 10. Twitter age + verification (0 now)
  results.push(await twitterAgeVerified(twitter));

  // 11. Discord roles (0 now)
  results.push(await discordRoles(discord));

  // Calculate total points out of 100
  const totalPoints = results.reduce((sum, item) => sum + (item.points || 0), 0);

  return {
    trustScore: totalPoints,
    breakdown: results
  };
}
