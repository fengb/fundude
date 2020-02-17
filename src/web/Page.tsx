import React from "react";
import useEvent from "react-use/lib/useEvent";

import nano from "./nano";

import App from "./App";
import AudioBench from "./AudioBench";
import Toaster from "./Toaster";

nano.putMany({
  "*": {
    boxSizing: "border-box",
    fontFamily: "inherit",
    margin: 0
  },
  html: {
    touchAction: "manipulation"
  },
  input: {
    maxWidth: "100%"
  },
  button: {
    cursor: "pointer"
  }
});

const CSS = {
  github: nano.rule({
    fontFamily: "Helvetica, 'Open Sans', Arial, sans-serif",
    fontWeight: 600,
    position: "fixed",
    left: "-50px",
    top: "40px",
    padding: "10px 40px",
    transform: "rotate(-45deg)",
    background: "rgba(15, 56, 15, .3333)",
    boxShadow: "0 0 2px currentColor",
    color: "rgb(15, 56, 15)",
    textDecoration: "none",
    transition: "200ms ease box-shadow",

    ":hover": {
      boxShadow: "0 0 5px 1px currentColor"
    }
  })
};

type DefaultRecord<K extends keyof any, T> = Record<K, T> & { default: T };

function route(
  location: Location,
  matches: DefaultRecord<string, () => React.ReactNode>
): React.ReactNode {
  for (let match in matches) {
    if (location.hash.includes(match)) {
      return matches[match]();
    }
  }
  return matches["default"]();
}

export default function Page() {
  const [_, setRerender] = React.useState(false);
  useEvent("hashchange", () => setRerender(val => !val));

  return (
    <Toaster.Provider show="topright">
      <a
        className={CSS.github}
        href="https://github.com/fengb/fundude"
        target="_blank"
      >
        Fork me on Github
      </a>
      {route(window.location, {
        audio: () => <AudioBench />,
        debug: () => <App debug />,
        default: () => <App />
      })}
    </Toaster.Provider>
  );
}
