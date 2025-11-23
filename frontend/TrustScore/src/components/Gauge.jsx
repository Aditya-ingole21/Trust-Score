import React, { useEffect, useRef } from 'react';

/**
 * Props:
 *  - value: number (0..100)
 *  - size: number (px)
 */
export default function Gauge({ value = 0, size = 240 }) {
  const ref = useRef(null);
  const radius = 80;
  const stroke = 14;
  const center = 100;
  const circumference = 2 * Math.PI * radius;
  const pct = Math.max(0, Math.min(100, value));

  // gradient id unique per instance (in case multiple)
  const gid = `g${Math.floor(Math.random() * 99999)}`;

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const circle = el.querySelector('.gauge-progress');
    // animate stroke-dashoffset
    const to = ((100 - pct) / 100) * circumference;
    // simple JS animation for smoothness
    circle.style.transition = 'stroke-dashoffset 900ms cubic-bezier(.17,.67,.1,1)';
    circle.style.strokeDashoffset = String(to);
  }, [pct, circumference]);

  // color mapping 0..100 -> gradient stops handled by svg gradient
  return (
    <svg ref={ref} width={size} height={size} viewBox="0 0 200 200">
      <defs>
        <linearGradient id={gid} x1="0" x2="1">
          <stop offset="0%" stopColor="#ff5a00" />
          <stop offset="50%" stopColor="#ffb400" />
          <stop offset="100%" stopColor="#ffd34d" />
        </linearGradient>
      </defs>

      {/* background arc */}
      <g transform="translate(0,0)">
        <circle cx={center} cy={center} r={radius} stroke="#1f2430" strokeWidth={stroke} fill="none" />
        {/* progress arc */}
        <circle
          className="gauge-progress"
          cx={center}
          cy={center}
          r={radius}
          stroke={`url(#${gid})`}
          strokeWidth={stroke}
          strokeLinecap="round"
          fill="none"
          strokeDasharray={`${circumference} ${circumference}`}
          strokeDashoffset={`${((100 - pct) / 100) * circumference}`}
          transform={`rotate(-90 ${center} ${center})`}
        />
        {/* center inner circle */}
        <circle cx={center} cy={center} r={radius - stroke - 6} fill="#07060a" stroke="rgba(255,255,255,0.02)" />
        {/* numeric label */}
        <text x={center} y={center - 4} textAnchor="middle" fontSize="28" fontWeight="700" fill="#fff">{pct}</text>
        <text x={center} y={center + 18} textAnchor="middle" fontSize="10" fill="#9aa0a6">TrustScore</text>
      </g>
    </svg>
  );
}
