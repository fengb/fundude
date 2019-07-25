import React from "react";
import cx from "classnames";
import { style } from "typestyle";
import { FixedSizeList } from "react-window";
import useDimensions from "react-use-dimensions";

import { fromEntries } from "../smalldash";

import FundudeWasm from "../../wasm";
import { hex2, hex4 } from "./util";

const CSS = {
  root: style({
    fontFamily: "monospace",
    display: "flex",
    flex: "1 1 auto"
  }),
  child: style({
    display: "flex",
    cursor: "pointer",

    $nest: {
      "&.active": {
        boxShadow: "inset 0 0 0 1px black"
      }
    }
  }),
  childSegment: style({
    margin: "0 4px"
  }),
  breakpoint: style({
    display: "inline-block",
    width: 10,
    height: 10,
    alignSelf: "center",

    $nest: {
      "&.active": {
        background: "red",
        borderRadius: "100%"
      }
    }
  })
};

export default function Disassembler(props: { fd: FundudeWasm }) {
  const currentAddr = props.fd.cpu().PC();
  const [assembly, setAssembly] = React.useState({} as Record<number, string>);

  React.useEffect(() => {
    const assembly = FundudeWasm.disassemble(props.fd.cart);
    setAssembly(fromEntries(assembly));
  }, [props.fd.cart]);

  const listRef = React.useRef<FixedSizeList>();
  React.useEffect(() => {
    listRef.current && listRef.current.scrollToItem(currentAddr);
  }, [listRef.current, currentAddr]);

  const [rootRef, { height }] = useDimensions();

  return (
    <div ref={rootRef} className={CSS.root}>
      <FixedSizeList
        ref={listRef}
        height={height || 0}
        width={240}
        itemSize={15}
        itemCount={props.fd.cart.length}
      >
        {({ index, style }) => (
          <div
            style={style}
            className={cx(CSS.child, index === currentAddr && "active")}
            onClick={() => props.fd.setBreakpoint(index)}
          >
            <i
              className={`${CSS.breakpoint} ${
                props.fd.breakpoint === index ? "active" : ""
              }`}
            />
            <span className={CSS.childSegment}>${hex4(index)}</span>
            <span className={CSS.childSegment}>
              {hex2(props.fd.cart[index])}
            </span>
            <strong className={CSS.childSegment}>
              {assembly[index] || ""}
            </strong>
          </div>
        )}
      </FixedSizeList>
    </div>
  );
}
