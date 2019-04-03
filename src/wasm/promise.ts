export function deferred<T>() {
  let resolve: (value?: T | PromiseLike<T> | undefined) => void;
  let reject: (reason?: any) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return Object.assign(promise, { resolve: resolve!, reject: reject! });
}
