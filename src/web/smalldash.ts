export function mapObject<E>(
  obj: any,
  callback: (value: any, key?: string) => E
): E[] {
  const result = [];
  for (const key in obj) {
    result.push(callback(obj[key], key));
  }
  return result;
}

type Indexable = string | number | symbol;

export function fromEntries<K extends Indexable, V>(
  entries: Iterable<[K, V]>
): Record<K, V> {
  const result = {} as Record<K, V>;
  for (const [key, value] of entries) {
    result[key] = value;
  }
  return result;
}

export function clamp(value: number, lower: number, upper: number) {
  if (value === value) {
    if (upper !== undefined) {
      value = value <= upper ? value : upper;
    }
    if (lower !== undefined) {
      value = value >= lower ? value : lower;
    }
  }

  return value;
}
