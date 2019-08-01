import "preact/debug";
import React from "react";
import { render } from "react-dom";
import App from "./App";

const container = document.getElementById("app");
if (container) {
  render(<App />, container);
}
