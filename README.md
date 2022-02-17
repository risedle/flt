# Fuse Leveraged Token

Leveraged Token powered by Rari Fuse.

## Install

Requires [dapptools](https://github.com/dapphub/dapptools#installation).

1. Clone the repository
   ```
   git clone git@github.com:risedle/flt.git
   cd flt/
   ```
2. Download all the dependencies
   ```
   dapp update
   ```
3. Configure and run the test

## Configure

Copy `.dapprc.example` to `.dapprc` and edit the `ETH_RPC_URL`.

## Extensions

If you are using Visual Studio Code, install the following extensions:

1. [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
   for code formatter.
2. [Solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity)
   for code highlight and more.

Then install the following packages:

    npm install -g solhint prettier prettier-plugin-solidity
