import React from "react";
import { keyBy, map } from "lodash";
import FundudeWasm, { GBInstruction } from "./wasm";
import LazyScroller from "./LazyScroller";

function formatAddr(addr: number) {
  return addr
    .toString(16)
    .padStart(4, "0")
    .toUpperCase();
}

function formatInstr(addr: number) {
  return addr
    .toString(16)
    .padStart(2, "0")
    .toUpperCase();
}

export default function Disassembler({ cart }: { cart: Uint8Array }) {
  const [assembly, setAssembly] = React.useState<Record<number, GBInstruction>>();

  React.useEffect(() => {
    FundudeWasm.boot(cart).then(fd => {
      Object.assign(window, { fd });
      const assembly = Array.from(fd.disassemble());
      setAssembly(keyBy(assembly, "addr"));
    });
  }, [cart]);

  return (
    <div>
      <h3>Cart size: {cart.length}</h3>
      <div style={{ fontFamily: "monospace" }}>
        {assembly ? (
          <LazyScroller childWidth={200} childHeight={15}>
            {map(cart, (instr, addr) => (
              <div key={addr}>
                <span style={{ color: "#aaa" }}>${formatAddr(addr)} </span>
                <span style={{ color: "#aaa" }}>{formatInstr(instr)} </span>
                <strong>{assembly[addr] && assembly[addr].text}</strong>
              </div>
            ))}
          </LazyScroller>
        ) : (
          <span>loading...</span>
        )}
      </div>
    </div>
  );
}
