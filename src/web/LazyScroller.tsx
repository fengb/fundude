import React from "react";
import useScroll from "react-use/lib/useScroll";
import { style } from "typestyle";

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
  children: React.ReactElement[];
}) {
  const [viewportHeight, setViewPortHeight] = React.useState<number>();
  const ref = React.useRef<HTMLDivElement>(null);
  const scroll = useScroll(ref);
  React.useEffect(() => {
    if (ref.current) {
      setViewPortHeight(ref.current.clientHeight);
    }
  }, [ref.current]);

  const scrollerStyle: React.CSSProperties = {
    width: props.childWidth,
    height: props.childHeight * props.children.length
  };

  function viewportOffset(i: number) {
    if (viewportHeight == null || scroll.y == null) {
      return 0;
    }
    const childTop = props.childHeight * i;
    const childBottom = childTop + props.childHeight;
    if (childTop < scroll.y) {
      return childTop - scroll.y;
    } else if (childBottom > scroll.y + viewportHeight) {
      return childBottom - scroll.y - viewportHeight;
    } else {
      return 0;
    }
  }

  const THRESHOLD = viewportHeight || 0;

  return (
    <div ref={ref} className={CSS.root}>
      <div className={CSS.scroller} style={scrollerStyle}>
        {props.children.map((child, i) => {
          if (Math.abs(viewportOffset(i)) > THRESHOLD) {
            return null;
          }
          return (
            <div
              key={child.key || i}
              className={CSS.child}
              style={{
                height: props.childHeight,
                top: props.childHeight * i
              }}
            >
              {child}
            </div>
          );
        })}
      </div>
    </div>
  );
}
