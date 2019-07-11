function asCart(hexString: string): Uint8Array {
  const result = new Uint8Array(32 * 1024);
  hexString
    .replace(/\s+/g, "")
    .match(/.{1,2}/g)!
    .forEach((s, i) => {
      result[i] = parseInt(s, 16);
    });
  return result;
}

export const BOOTLOADER = asCart(`
31 FE FF AF 21 FF 9F 32 CB 7C 20 FB 21 26 FF 0E
11 3E 80 32 E2 0C 3E F3 E2 32 3E 77 77 3E FC E0
47 11 04 01 21 10 80 1A CD 95 00 CD 96 00 13 7B
FE 34 20 F3 11 D8 00 06 08 1A 13 22 23 05 20 F9
3E 19 EA 10 99 21 2F 99 0E 0C 3D 28 08 32 0D 20
F9 2E 0F 18 F3 67 3E 64 57 E0 42 3E 91 E0 40 04
1E 02 0E 0C F0 44 FE 90 20 FA 0D 20 F7 1D 20 F2
0E 13 24 7C 1E 83 FE 62 28 06 1E C1 FE 64 20 06
7B E2 0C 3E 87 E2 F0 42 90 E0 42 15 20 D2 05 20
4F 16 20 18 CB 4F 06 04 C5 CB 11 17 C1 CB 11 17
05 20 F5 22 23 22 23 C9 CE ED 66 66 CC 0D 00 0B
03 73 00 83 00 0C 00 0D 00 08 11 1F 88 89 00 0E
DC CC 6E E6 DD DD D9 99 BB BB 67 63 6E 0E EC CC
DD DC 99 9F BB B9 33 3E 3C 42 B9 A5 B9 A5 42 3C
21 04 01 11 A8 00 1A 13 BE 20 FE 23 7D FE 34 20
F5 06 19 78 86 23 05 20 FB 86 20 FE 3E 01 E0 50

00 00 00 00

FF CF 66 66 DD DD 99 DF 88 8B 0C C3 77 66 9D DD
BB BB 77 66 9D DD EE 8E FC CC 66 73 DD D9 B9 99
B8 88 3C C0 66 77 DD D8 BB FE 66 77 DD D9 E8 EE
`);
