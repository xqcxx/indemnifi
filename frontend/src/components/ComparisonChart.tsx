"use client";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from "recharts";

interface ComparisonChartProps {
  aliceFinalLoss: number;
  bobFinalLoss: number;
}

/** Alice (uninsured) vs Bob (insured) final-loss comparison. */
export function ComparisonChart({ aliceFinalLoss, bobFinalLoss }: ComparisonChartProps) {
  const data = [
    { name: "Alice (uninsured)", loss: Math.round(aliceFinalLoss), fill: "rgba(255,255,255,0.25)" },
    { name: "Bob (insured)", loss: Math.round(bobFinalLoss), fill: "#fb27ce" },
  ];

  return (
    <div className="h-64 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 8, right: 8, left: 0, bottom: 8 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" vertical={false} />
          <XAxis
            dataKey="name"
            tick={{ fill: "rgba(255,255,255,0.5)", fontSize: 12, fontWeight: 700 }}
            axisLine={{ stroke: "rgba(255,255,255,0.08)" }}
            tickLine={false}
          />
          <YAxis
            tick={{ fill: "rgba(255,255,255,0.35)", fontSize: 11, fontWeight: 600 }}
            axisLine={false}
            tickLine={false}
            tickFormatter={(v) => `$${v}`}
          />
          <Tooltip
            cursor={{ fill: "rgba(255,255,255,0.04)" }}
            contentStyle={{
              background: "#111",
              border: "1px solid rgba(255,255,255,0.08)",
              borderRadius: 12,
              fontWeight: 600,
            }}
            labelStyle={{ color: "#fff", fontWeight: 800 }}
            formatter={(v) => [`$${Number(v).toLocaleString()}`, "Final loss"]}
          />
          <Bar dataKey="loss" radius={[8, 8, 0, 0]}>
            {data.map((d, i) => (
              <Cell key={i} fill={d.fill} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
