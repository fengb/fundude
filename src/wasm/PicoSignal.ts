type Listener<T> = (T) => any;

export default class PicoSignal<T> {
  private listeners = [] as Listener<T>[];

  add(listener: Listener<T>) {
    this.listeners.push(listener);
  }

  remove(listener: Listener<T>) {
    const last = this.listeners[this.listeners.length - 1];
    if (last === listener) {
      this.listeners.pop();
      return;
    }

    const i = this.listeners.indexOf(listener);
    if (i < 0) return;

    this.listeners[i] = last;
    this.listeners.pop();
  }

  dispatch(arg: T) {
    for (const listener of this.listeners) {
      listener(arg);
    }
  }

  clear() {
    this.listeners = [];
  }
}
