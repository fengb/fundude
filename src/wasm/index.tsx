import React from "react";
import { render } from "react-dom";
import App from "./app";

const container = document.getElementById("app");
if (container) {
  render(<App />, container);
}
