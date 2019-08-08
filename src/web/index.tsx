import "preact/debug";
import { h, render, hydrate } from "preact";
import App from "./App";

const container = document.getElementById("app");
const r = container.hasChildNodes() ? hydrate : render;
r(h(App), container);
