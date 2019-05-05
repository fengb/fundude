import React from "react";
import { render } from "react-dom";
import { forceRenderStyles } from "typestyle";
import App from "./App";

const container = document.getElementById("app");
if (container) {
  forceRenderStyles();
  render(<App debug={window.location.hash.includes("debug")} />, container);
}
