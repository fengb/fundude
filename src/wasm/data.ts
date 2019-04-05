function asBitArray(hexString: string): Uint8Array {
  const bytes = hexString
    .replace(/\s+/g, "")
    .match(/.{1,2}/g)!
    .map(s => parseInt(s, 16));

  return new Uint8Array(bytes);
}

export const EMPTY = asBitArray("00".repeat(32 * 1024));
