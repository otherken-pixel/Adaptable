/**
 * Deterministic, appetizing cover gradients — every recipe gets a stable
 * pair derived from its id, so cards look designed without image assets.
 */
const PALETTES: Array<[string, string]> = [
  ["#FF9A62", "#F0432C"], // ember
  ["#FFC148", "#F07C22"], // saffron
  ["#7BD88F", "#1F9D6B"], // herb
  ["#67C5E8", "#2D6CDF"], // tide
  ["#C48BF0", "#7D3CE8"], // ube
  ["#FF8FB1", "#E4426E"], // hibiscus
  ["#F6D365", "#FDA085"], // apricot
  ["#84FAB0", "#8FD3F4"], // matcha mist
];

export function coverGradient(seed: string): string {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) | 0;
  }
  const [from, to] = PALETTES[Math.abs(hash) % PALETTES.length];
  return `linear-gradient(135deg, ${from} 0%, ${to} 100%)`;
}
