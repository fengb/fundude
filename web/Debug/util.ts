export function hex2(n: number) {
  return n
    .toString(16)
    .toUpperCase()
    .padStart(2, "0");
}

export function hex4(n: number) {
  return n
    .toString(16)
    .toUpperCase()
    .padStart(4, "0");
}
