import React from "react";
import useScroll from "react-use/lib/useScroll";

const STYLES: React.CSSProperties = {
  maxHeight: "100vh",
  overflowY: "auto"
};

export default function LazyScroller(props: {
  childWidth: number;
  childHeight: number;
  children: React.ReactElement[];
  className?: string;
  style?: React.CSSProperties;
}) {
  const [viewportHeight, setViewPortHeight] = React.useState<number>();
  const ref = React.useRef<HTMLDivElement>(null);
  const scroll = useScroll(ref);
  function updateDimensions() {
    if (ref.current) {
      setViewPortHeight(ref.current.clientHeight);
    }
  }
  React.useEffect(updateDimensions, [ref.current]);

  const scrollerStyle: React.CSSProperties = {
    position: "relative",
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
  const children = props.children.map((child, i) => {
    if (Math.abs(viewportOffset(i)) > THRESHOLD) {
      return null;
    }
    return (
      <div
        key={child.key || i}
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          height: props.childHeight,
          top: props.childHeight * i
        }}
      >
        {child}
      </div>
    );
  });

  return (
    <div ref={ref} className={props.className} style={STYLES}>
      <div style={scrollerStyle}>{children}</div>
    </div>
  );
}
