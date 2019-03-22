FROM trzeci/emscripten-slim

RUN apt-get -y update \
 && apt-get install -y --no-install-recommends \
        make \
 && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json /src/
RUN npm install

COPY . /src
