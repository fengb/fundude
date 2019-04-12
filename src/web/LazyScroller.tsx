import React from "react";
import useScroll from "react-use/lib/useScroll";
import { style } from "typestyle";
import { range, clamp } from "lodash";

const CSS = {
  root: style({
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
  })
};

export default function LazyScroller(props: {
  childWidth: number;
  childHeight: number;
  totalChildren: number;
  focus?: number;
  children: (i: number) => React.ReactNode;
}) {
  const [viewportHeight, setViewPortHeight] = React.useState(0);
  const ref = React.useRef<HTMLDivElement>(null);
  const scroll = useScroll(ref);

  React.useEffect(() => {
    if (ref.current) {
      setViewPortHeight(ref.current.clientHeight);
    }
  }, [ref.current]);
  React.useEffect(() => {
    if (!ref.current || !props.focus) {
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

  function displayableItems(threshold = viewportHeight) {
    const head = (scroll.y - threshold) / props.childHeight;
    const tail = (scroll.y + viewportHeight + threshold) / props.childHeight;
    return range(
      Math.max(Math.floor(head), 0),
      Math.min(Math.floor(tail), props.totalChildren)
    );
  }

  return (
    <div ref={ref} className={CSS.root}>
      <div className={CSS.scroller} style={scrollerStyle}>
        {displayableItems().map(item => (
          <div
            key={item}
            className={CSS.child}
            style={{
              height: props.childHeight,
              top: props.childHeight * item
            }}
          >
            {props.children(item)}
          </div>
        ))}
        {props.focus != undefined && (
          <div
            className={CSS.child}
            style={{
              height: props.childHeight,
              top: props.childHeight * props.focus,
              boxShadow: "inset 0 0 0 1px black"
            }}
          />
        )}
      </div>
    </div>
  );
}
