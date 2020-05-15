import React from "react";

import { fromEntries } from "./smalldash";

type Omit<T, K> = Pick<T, Exclude<keyof T, K>>;

export default function Form({
  onSubmit,
  children,
  ...props
}: Omit<React.HTMLAttributes<HTMLFormElement>, "onSubmit"> & {
  onSubmit: (data: Record<string, FormDataEntryValue>) => any;
  children: React.ReactNode;
}) {
  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fd = new FormData(event.currentTarget);
    onSubmit(fromEntries(fd));
  }
  return (
    <form onSubmit={handleSubmit} {...props}>
      {children}
    </form>
  );
}
