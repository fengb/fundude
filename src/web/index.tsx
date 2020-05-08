if (process.env.NODE_ENV==='development') {
  require("preact/debug");
}
import { h, render, hydrate } from "preact";
import Page from "./Page";

const container = document.getElementById('app');
const r = container.hasChildNodes() ? hydrate : render;
r(h(Page), container);
