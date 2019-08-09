import { h } from "preact";
import { create } from "nano-css";

import { addon as addonRule } from "nano-css/addon/rule";
import { addon as addonCache } from "nano-css/addon/cache";
import { addon as addonNesting } from "nano-css/addon/nesting";
import { CssLikeObject } from "nano-css/types/common";

const nano = create({ h });

addonRule(nano);
addonCache(nano);
addonNesting(nano);

export default Object.assign(nano, {
  putMany(obj: Record<string, CssLikeObject>) {
    for (const key in obj) {
      nano.put(key, obj[key]);
    }
  }
});
