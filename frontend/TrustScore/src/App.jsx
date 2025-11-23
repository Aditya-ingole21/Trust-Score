import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount } from 'wagmi';

function App() {
  const { address, isConnected } = useAccount();

  return (
    <div className="min-h-screen bg-black text-white flex flex-col items-center justify-center gap-6">
      <h1 className="text-3xl font-bold">TrustScore Loans</h1>

      <ConnectButton />

      {isConnected && (
        <div className="text-center">
          <p>Connected Wallet:</p>
          <p className="text-green-400">{address}</p>
        </div>
      )}
    </div>
  );
}

export default App;
