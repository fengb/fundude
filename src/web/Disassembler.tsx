import React from "react";
import FundudeWasm from "./wasm";

export default function Disassembler({ cart }: { cart: Uint8Array }) {
  const [assembly, setAssembly] = React.useState(["loading..."]);

  React.useEffect(() => {
    FundudeWasm.boot(cart).then(fd => {
      setAssembly(Array.from(fd.disassemble()).map(String));
    });
  }, [cart]);

  return (
    <div>
      <h3>{cart.length}</h3>
      {assembly.map((s, i) => (
        <div key={i}>{s}</div>
      ))}
    </div>
  );
}
