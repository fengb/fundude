function asBitArray(hexString: string): Uint8Array {
  const bytes = hexString
    .replace(/\s+/g, "")
    .match(/.{1,2}/g)!
    .map(s => parseInt(s, 16));

  return new Uint8Array(bytes);
}

export const BOOTLOADER = asBitArray(`
31 fe ff af 21 ff 9f 32 cb 7c 20 fb 21 26 ff 0e
11 3e 80 32 e2 0c 3e f3 e2 32 3e 77 77 3e fc e0
47 11 04 01 21 10 80 1a cd 95 00 cd 96 00 13 7b
fe 34 20 f3 11 d8 00 06 08 1a 13 22 23 05 20 f9
3e 19 ea 10 99 21 2f 99 0e 0c 3d 28 08 32 0d 20
f9 2e 0f 18 f3 67 3e 64 57 e0 42 3e 91 e0 40 04
1e 02 0e 0c f0 44 fe 90 20 fa 0d 20 f7 1d 20 f2
0e 13 24 7c 1e 83 fe 62 28 06 1e c1 fe 64 20 06
7b e2 0c 3e 87 e2 f0 42 90 e0 42 15 20 d2 05 20
4f 16 20 18 cb 4f 06 04 c5 cb 11 17 c1 cb 11 17
05 20 f5 22 23 22 23 c9 ce ed 66 66 cc 0d 00 0b
03 73 00 83 00 0c 00 0d 00 08 11 1f 88 89 00 0e
dc cc 6e e6 dd dd d9 99 bb bb 67 63 6e 0e ec cc
dd dc 99 9f bb b9 33 3e 3c 42 b9 a5 b9 a5 42 3c
21 04 01 11 a8 00 1a 13 be 20 fe 23 7d fe 34 20
f5 06 19 78 86 23 05 20 fb 86 20 fe 3e 01 e0 50
`);
