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
  const [assembly, setAssembly] = React.useState<Record<number, GBInstruction>>();

  React.useEffect(() => {
    FundudeWasm.boot(cart).then(fd => {
      Object.assign(window, { fd });
      const assembly = Array.from(fd.disassemble());
      setAssembly(keyBy(assembly, "addr"));
    });
  }, [cart]);

  return (
    <div className={CSS.root}>
      {assembly ? (
        <LazyScroller childWidth={200} childHeight={15}>
          {map(cart, (instr, addr) => (
            <div key={addr}>
              <span className={CSS.addr}>${formatAddr(addr)} </span>
              <span className={CSS.instr}>{formatInstr(instr)} </span>
              <strong>{assembly[addr] && assembly[addr].text}</strong>
            </div>
          ))}
        </LazyScroller>
      ) : (
        <span>loading...</span>
      )}
    </div>
  );
}
