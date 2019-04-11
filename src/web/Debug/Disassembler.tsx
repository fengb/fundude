import React from "react";
import { keyBy, map } from "lodash";
import { style } from "typestyle";
import FundudeWasm, { GBInstruction } from "../wasm";
import LazyScroller from "../LazyScroller";

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

const CSS = {
  root: style({
    fontFamily: "monospace",
    height: "100%"
  }),
  addr: style({
    color: "#aaa"
  }),
  instr: style({
    color: "#aaa"
  })
};

export default function Disassembler({ cart }: { cart: Uint8Array }) {
  const [assembly, setAssembly] = React.useState(
    {} as Record<number, GBInstruction>
  );

  React.useEffect(() => {
    FundudeWasm.ready().then(() => {
      const assembly = Array.from(FundudeWasm.disassemble(cart));
      setAssembly(keyBy(assembly, "addr"));
    });
  }, [cart]);

  return (
    <div className={CSS.root}>
      <LazyScroller childWidth={200} childHeight={15} totalChildren={cart.length} focus={50}>
        {addr => (
          <div>
            <span className={CSS.addr}>${formatAddr(addr)} </span>
            <span className={CSS.instr}>{formatInstr(cart[addr])} </span>
            <strong>{assembly[addr] && assembly[addr].text}</strong>
          </div>
        )}
      </LazyScroller>
    </div>
  );
}
