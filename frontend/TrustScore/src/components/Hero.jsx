import React from 'react';

export default function Hero({ score }) {
  return (
    <section className="app-bg min-h-[56vh] flex items-center">
      <div className="container mx-auto px-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
          <div>
            <div className="mb-4">
              <span className="badge">⚠️ HIGH VOLTAGE</span>
            </div>

            <h1 className="text-white font-display leading-tight" style={{fontWeight:900, fontSize: '6.5rem', lineHeight: '0.88' }}>
              <span className="block text-7xl md:text-[4.6rem]">YOUR CREDIT</span>
              <span className="block text-8xl md:text-[6rem]">REIMAGINED</span>
              <span className="block headline-gradient glow-accent text-[6rem] md:text-[8rem]">FOR WEB3.</span>
            </h1>

            <p className="mt-6 text-lg muted max-w-xl">
              Our TrustScore doesn't sugarcoat. Borrow like a bank using reputation — no KYC required.
            </p>

            <div className="mt-8 flex gap-4">
              <button className="px-6 py-3 rounded-md bg-gradient-to-r from-[#ff5a00] to-[#ffb400] font-semibold shadow-glow-orange">
                Borrow demo
              </button>
              <button className="px-6 py-3 rounded-md border border-white/10 text-white/90">
                Learn more
              </button>
            </div>
          </div>

          <div className="flex flex-col items-center justify-center gap-6">
            {/* will render Gauge component from parent */}
            {score !== undefined ? (
              <div className="panel p-6 rounded-2xl w-72 h-72 flex items-center justify-center">
                {typeof score === 'number' ? (
                  <div className="w-full h-full flex items-center justify-center">
                    <div id="gauge-placeholder" />
                  </div>
                ) : <div className="muted">Sign in to see your TrustScore</div>}
              </div>
            ) : (
              <div className="muted">Loading...</div>
            )}
          </div>

        </div>
      </div>
    </section>
  );
}
