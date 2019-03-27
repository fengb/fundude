FROM trzeci/emscripten

COPY package.json package-lock.json /src/
RUN npm install

COPY . /src
