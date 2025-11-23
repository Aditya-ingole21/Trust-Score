import React, { useEffect, useState } from "react";
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount } from 'wagmi';
import Hero from './components/Hero';
import Gauge from './components/Gauge';

export default function App() {
  const { address, isConnected } = useAccount();
  const [scoreObj, setScoreObj] = useState(null);

  useEffect(() => {
    if (!address) {
      setScoreObj(null);
      return;
    }

    // fetch from backend
    (async () => {
      try {
        const res = await fetch(`http://localhost:5000/api/score?address=${address}`);
        if (!res.ok) throw new Error('score fetch failed');
        const data = await res.json();
        setScoreObj(data);
      } catch (err) {
        console.error('fetch score error', err);
      }
    })();
  }, [address]);

  return (
    <div className="min-h-screen app-bg">
      <header className="px-6 py-4 flex justify-between items-center">
        <div className="text-2xl font-bold text-white">TRUSTSCORE</div>
        <div><ConnectButton /></div>
      </header>

      <main>
        <Hero score={scoreObj ? scoreObj.trustScore : undefined} />
        <section className="py-12">
          <div className="container mx-auto px-6">
            <div className="flex items-center justify-center">
              { scoreObj ? (
                <div className="panel p-8 rounded-2xl">
                  <div className="flex items-center gap-8">
                    <Gauge value={scoreObj.trustScore} size={220} />
                    <div>
                      <h3 className="text-2xl font-semibold">Your TrustScore: <span className="headline-gradient">{scoreObj.trustScore}</span></h3>
                      <p className="muted mt-2">Issued: {new Date(scoreObj.issuedAt * 1000).toLocaleString()}</p>
                      <p className="muted mt-1">Signature: <span className="muted break-all" style={{maxWidth: 380}}>{scoreObj.signature}</span></p>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="text-center muted">Connect your wallet to fetch TrustScore</div>
              )}
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
