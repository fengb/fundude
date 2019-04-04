import React from "react";
import Display from "./display";
import { EMPTY } from "./data";
import FundudeWasm from "./core";

export default function() {
  const [fd, setFd] = React.useState<FundudeWasm>();
  React.useEffect(() => {
    FundudeWasm.boot(EMPTY).then(setFd);
  }, []);

  return <div>{fd && <Display fundude={fd} />}</div>;
}
