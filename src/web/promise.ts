export function deferred<T>() {
  let resolve: (value?: T | PromiseLike<T> | undefined) => void;
  let reject: (reason?: any) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return Object.assign(promise, { resolve: resolve!, reject: reject! });
}

export function nextAnimationFrame() {
  return new Promise(requestAnimationFrame);
}

export function readAsArray(file: File) {
  const reader = new FileReader();
  return new Promise<ArrayBuffer>((resolve, reject) => {
    reader.onload = evt => resolve((evt as any).target.result);
    reader.onerror = reject;
    reader.readAsArrayBuffer(file);
  });
}
