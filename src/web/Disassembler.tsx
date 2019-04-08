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
      Object.assign(window, { fd });
      setAssembly(Array.from(fd.disassemble()));
    });
  }, [cart]);

  return (
    <div>
      <h3>Cart size: {cart.length}</h3>
      <div style={{ fontFamily: "monospace" }}>
        {assembly ? (
          assembly.map(instr => (
            <div key={instr.addr}>
              <span style={{color: "#aaa"}}>${formatAddr(instr.addr)}</span>
              <strong> {instr.text}</strong>
            </div>
          ))
        ) : (
          <span>loading...</span>
        )}
      </div>
    </div>
  );
}
