# ![FUN DUDE](src/web/logo.svg) <br> 🚧 Under Construction 🚧

### Game compatibility

Perfect emulation:
- _none_

Playable:
- **Tetris**
- **Super Mario Land**
- **Bionic Commando**

### Implementation details

| | |
|-|-|
| CPU | some bugs, incorrect instruction durations |
| PPU | mostly working -- render hacks |
| Joypad | should work |
| Timer | untested, poor timing |
| Interrupts | untested |
| Serial | ❌ |
| Audio | ❌ |

### Development

Dependencies:
- zig 0.6.0+
- node.js 10.0.0+

```bash
# Pull down this project
$ git clone https://github.com/fengb/fundude.git
$ cd fundude

# Build the wasm -- release-safe increases performance by >10x compared to the default debug mode
$ zig build -Drelease-safe

# Start the server
$ yarn install
$ yarn dev
```
