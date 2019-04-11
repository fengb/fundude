import React from "react";
import { keyBy } from "lodash";
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

export default function Disassembler(props: {
  cart: Uint8Array;
  programCounter: number;
}) {
  const [assembly, setAssembly] = React.useState(
    //
    {} as Record<number, GBInstruction>
  );

  React.useEffect(() => {
    FundudeWasm.ready().then(() => {
      const assembly = Array.from(FundudeWasm.disassemble(props.cart));
      setAssembly(keyBy(assembly, "addr"));
    });
  }, [props.cart]);

  return (
    <div className={CSS.root}>
      <LazyScroller
        childWidth={200}
        childHeight={15}
        totalChildren={props.cart.length}
        focus={props.programCounter}
      >
        {addr => (
          <div>
            <span className={CSS.addr}>${formatAddr(addr)} </span>
            <span className={CSS.instr}>{formatInstr(props.cart[addr])} </span>
            <strong>{assembly[addr] && assembly[addr].text}</strong>
          </div>
        )}
      </LazyScroller>
    </div>
  );
}
