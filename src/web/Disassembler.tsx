import React from "react";
import FundudeWasm, { GBInstruction } from "./wasm";

function formatAddr(addr: number) {
  return addr
    .toString(16)
    .padStart(4, "0")
    .toUpperCase();
}

export default function Disassembler({ cart }: { cart: Uint8Array }) {
  const [assembly, setAssembly] = React.useState<GBInstruction[]>();

  React.useEffect(() => {
    FundudeWasm.boot(cart).then(fd => {
      setAssembly(Array.from(fd.disassemble()));
    });
  }, [cart]);

  return (
    <div>
      <h3>{cart.length}</h3>
      {assembly ? (
        assembly.map(instr => (
          <div key={instr.addr}>
            <span>${formatAddr(instr.addr)}</span>
            <span> {instr.text}</span>
          </div>
        ))
      ) : (
        <span>loading...</span>
      )}
    </div>
  );
}
