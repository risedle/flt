# Fuse Leveraged Token

Leveraged Token powered by Rari Fuse.

## Setup

Requires [foundry](https://github.com/gakonst/foundry#installation).

1. Clone the repository
   ```
   git clone git@github.com:risedle/flt.git
   cd flt/
   ```
2. Download all the dependencies
   ```
   forge update
   ```

## Testing

Run the following command to run the test:

    forge test --fork-url ALCHEMY_URL --fork-block-number BLOCK_NUMBER

Use blocknumber `14615745` to test before Rari Fuse hack.

## Code Editor

If you are using Visual Studio Code, install the following extensions:

1. [Solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity)
   for code highlight and more.
