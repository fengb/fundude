FROM ubuntu:19.04

RUN apt-get update \
    && apt-get install -y \
               clang-8 \
               lld-8 \
               make \
    && rm -rf /var/lib/apt/lists/*

RUN cp /usr/bin/clang-8 /usr/bin/clang
RUN cp /usr/bin/wasm-ld-8 /usr/bin/wasm-ld

RUN mkdir -p /opt/fundude

WORKDIR /opt/fundude

ENV MAKEFLAGS=-j4
