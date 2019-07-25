import React from "react";
import useScroll from "react-use/lib/useScroll";
import { style } from "typestyle";

import clamp from "lodash/clamp";
import times from "lodash/times";

const CSS = {
  root: style({
    flex: "1",
    height: "100%",
    maxHeight: "100vh",
    overflowY: "auto"
  }),
  scroller: style({
    position: "relative"
  }),
  child: style({
    position: "absolute",
    left: 0,
    right: 0
  }),
  focus: style({
    position: "absolute",
    left: 0,
    right: 0,
    boxShadow: "inset 0 0 0 1px black",
    pointerEvents: "none"
  })
};

export default function LazyScroller(props: {
  childWidth: number;
  childHeight: number;
  threshold?: number;
  totalChildren: number;
  focus?: number;
  children: (i: number) => React.ReactNode;
}) {
  const [viewportHeight, setViewPortHeight] = React.useState(0);
  const ref = React.useRef<HTMLDivElement>(null);
  const scroll = useScroll(ref);
  const threshold = props.threshold || viewportHeight * 0.5;

  React.useEffect(() => {
    if (ref.current) {
      setViewPortHeight(ref.current.clientHeight);
    }
  }, [ref.current]);
  React.useEffect(() => {
    if (ref.current == null || props.focus == null) {
      return;
    }

    ref.current.scrollTop = clamp(
      ref.current.scrollTop,
      (props.focus + 1) * props.childHeight - viewportHeight,
      props.focus * props.childHeight
    );
  }, [props.focus]);

  const scrollerStyle: React.CSSProperties = {
    width: props.childWidth,
    height: props.childHeight * props.totalChildren
  };

  const start = Math.floor((scroll.y - threshold) / props.childHeight);
  const toDisplay = Math.ceil(
    (2 * threshold + viewportHeight) / props.childHeight
  );

  return (
    <div ref={ref} className={CSS.root}>
      <div className={CSS.scroller} style={scrollerStyle}>
        {times(toDisplay, i => {
          i += start;
          const hasChild = 0 <= i && i < props.totalChildren;
          const key = (i + toDisplay) % toDisplay;
          return (
            hasChild && (
              <div
                key={key}
                className={CSS.child}
                style={{
                  height: props.childHeight,
                  top: hasChild && props.childHeight * i
                }}
              >
                {hasChild && props.children(i)}
              </div>
            )
          );
        })}
        {props.focus != undefined && (
          <div
            className={CSS.focus}
            style={{
              height: props.childHeight,
              top: props.childHeight * props.focus
            }}
          />
        )}
      </div>
    </div>
  );
}
