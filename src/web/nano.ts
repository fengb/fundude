import { create } from "nano-css";

import { addon as addonRule } from "nano-css/addon/rule";
import { addon as addonCache } from "nano-css/addon/cache";
import { addon as addonHydrate } from "nano-css/addon/hydrate";
import { addon as addonNesting } from "nano-css/addon/nesting";
import { CssLikeObject } from "nano-css/types/common";

const nano = create({
  pfx: "fd",
  sh: document.getElementById("nano-css") as any
});

addonRule(nano);
addonCache(nano);
addonHydrate(nano);
addonNesting(nano);

export default Object.assign(nano, {
  putMany(obj: Record<string, CssLikeObject>) {
    for (const key in obj) {
      nano.put(key, obj[key]);
    }
  }
});
