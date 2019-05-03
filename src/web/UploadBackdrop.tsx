import React from "react";
import classnames from "classnames";
import { style } from "typestyle";
import { useDropzone, DropzoneOptions, DropzoneState } from "react-dropzone";

const CSS = {
  backdrop: style({
    position: "fixed",
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    background: "#000000",
    opacity: 0,
    transition: "300ms ease-in opacity",
    pointerEvents: "none",

    $nest: {
      "&.active": {
        pointerEvents: "initial",
        opacity: 0.8
      }
    }
  })
};

type FuncNode<T> = React.ReactNode | ((T) => React.ReactNode);

export default function UploadBackdrop(props: {
  dropzone: DropzoneOptions;
  className?: string;
  active: boolean;
  clickBackdrop?: () => any;
  children?: FuncNode<DropzoneState>;
}) {
  const dropzone = useDropzone({ ...props.dropzone, noClick: true });
  return (
    <div className={props.className} {...dropzone.getRootProps()}>
      <input {...dropzone.getInputProps()} />

      <div
        className={classnames(CSS.backdrop, props.active && "active")}
        onClick={props.clickBackdrop}
      />

      {typeof props.children == "function"
        ? props.children(dropzone)
        : props.children}
    </div>
  );
}
