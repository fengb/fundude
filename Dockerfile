FROM trzeci/emscripten-slim

COPY package.json package-lock.json /src/
RUN npm install

COPY . /src
