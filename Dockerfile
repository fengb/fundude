FROM ubuntu:19.04

RUN apt-get update && apt-get install -y \
    xz-utils \
    wget \
 && rm -rf /var/lib/apt/lists/*
RUN mkdir /opt/zig
RUN ln -s /opt/zig/zig /usr/local/bin

RUN xargs wget -qO- https://ziglang.org/builds/zig-linux-x86_64-0.5.0+4d54e9a4f.tar.xz \
    | tar xJ --directory /opt/zig --strip-components=1

WORKDIR /app
