// tailwind.config.cjs
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,jsx,ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        'bg-black': '#070606',
        'panel': '#0f0e10',
        'accent-start': '#ff5a00', // orange
        'accent-mid': '#ffb400',   // yellow-orange
        'accent-end': '#ffd34d',   // soft yellow
        'muted': '#9aa0a6'
      },
      fontFamily: {
        display: ['Inter', 'ui-sans-serif', 'system-ui'],
        headline: ['"Oswald"', 'sans-serif']
      },
      boxShadow: {
        'glow-orange': '0 6px 30px rgba(255,90,0,0.18)',
        'panel': '0 8px 40px rgba(0,0,0,0.6)'
      }
    }
  },
  plugins: []
}
