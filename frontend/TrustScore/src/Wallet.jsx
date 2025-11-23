import '@rainbow-me/rainbowkit/styles.css';

import {
  RainbowKitProvider,
  getDefaultWallets,
} from '@rainbow-me/rainbowkit';

import {
  WagmiConfig,
  http,
  createConfig,
} from 'wagmi';

import { base } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const projectId = 'trustscore-connect';

// Create query client (required by RainbowKit)
const queryClient = new QueryClient();

// Supported chains
const chains = [base];

// RainbowKit wallets
const { wallets } = getDefaultWallets({
  appName: 'TrustScore Loans',
  projectId,
  chains,
});

// wagmi config
export const wagmiConfig = createConfig({
  chains,
  transports: {
    [base.id]: http(),
  },
  wallets,
  autoConnect: true,
});

// Provider wrapper
export function Web3Provider({ children }) {
  return (
    <QueryClientProvider client={queryClient}>
      <WagmiConfig config={wagmiConfig}>
        <RainbowKitProvider chains={chains}>
          {children}
        </RainbowKitProvider>
      </WagmiConfig>
    </QueryClientProvider>
  );
}
