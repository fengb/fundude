import { h } from "preact";
import { create } from "nano-css";

import { addon as addonRule } from "nano-css/addon/rule";
import { addon as addonCache } from "nano-css/addon/cache";
import { addon as addonNesting } from "nano-css/addon/nesting";

const nano = create({ h });

addonRule(nano);
addonCache(nano);
addonNesting(nano);

export default nano;
