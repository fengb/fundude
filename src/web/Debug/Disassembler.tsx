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
  }),
  breakpoint: style({
    background: "red"
  })
};

export default function Disassembler(props: { fd: FundudeWasm }) {
  const [assembly, setAssembly] = React.useState(
    //
    {} as Record<number, GBInstruction>
  );

  React.useEffect(() => {
    FundudeWasm.ready().then(() => {
      const assembly = Array.from(FundudeWasm.disassemble(props.fd.cart));
      setAssembly(keyBy(assembly, "addr"));
    });
  }, [props.fd.cart]);

  return (
    <div className={CSS.root}>
      <LazyScroller
        childWidth={200}
        childHeight={15}
        totalChildren={props.fd.cart.length}
        focus={props.fd.programCounter}
      >
        {addr => (
          <div
            className={props.fd.breakpoint === addr ? CSS.breakpoint : ""}
            onClick={() => props.fd.setBreakpoint(addr)}
          >
            <span className={CSS.addr}>${formatAddr(addr)} </span>
            <span className={CSS.instr}>
              {formatInstr(props.fd.cart[addr])}{" "}
            </span>
            <strong>{assembly[addr] && assembly[addr].text}</strong>
          </div>
        )}
      </LazyScroller>
    </div>
  );
}
