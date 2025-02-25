# stylus-zig-erc20
A zig stylus program of ERC20 token and partial functions of simple stylus zig sdk example implementation.

## build
```bash
zig build-exe ./src/main.zig -target wasm32-freestanding -fno-entry --export=user_entrypoint -OReleaseSmall
```
zig version: 0.13.0


## Note
This repo is only for demo, and the stylus zig sdk (wax) under ./src/tiny-zig-sdk-wax should not be used directly on any production/mainnet deployment as it doesn't get any audit.
