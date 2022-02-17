# Fuse Leveraged Tokens

This document contains the initial design of Risedle Leveraged Tokens V2 or
Fuse Leveraged Tokens (FLT).

## Overview

Fuse Leveraged Tokens (FLT) is a structured products created by [Risedle](https://risedle.com)
built on top of [Rari Fuse](https://rari.app/fuse) in the Tribe ecosystem.

Fuse Leveraged Tokens (FLT) aims to simplify the process of opening, managing,
closing leveraged position and protect users from liquidation. By letting users
mint Fuse Leveraged Tokens, Risedle can helps users to enjoy leveraged gains by
simply holding a token and eliminate the intricacies of managing a conventional
leveraged position as users are not required to maintain margin or their position
health ratio.

## Background

Risedle launch its first leveraged token (v1), ETHRISE 2x Long ETH token, using its
own lending-borrowing contract (Risedle Vaults) on Arbitrum One mainnet.
Risedle Vault is simplified version lending-borrowing protocol that specially
designed for leveraged tokens.

so, why Risedle build its leveraged token v2 on top of Fuse?

### Fuse > Risedle Vault

Fuse is is a protocol that supports isolated interest rate pools. Fuse allows
pool creators to spin up customized, isolated pools for lending and borrowing
assets of their choice. Pool creators can choose all the unique parameters
they want: interest rate curves, oracles, collateral factors, etc.

This is exactly how Risedle Vault work, so instead of we maintain the
lending-borrowing contract ourselves we just build on top of Fuse and focus
on the products instead.

We envisioned on-chain leveraged tokens market should support all natives asset
on its chain as long as it have enough liquidity. Fuse allows Risedle to do this
in a battle-tested way.

The next inmportant thing is capital efficiency. When user lend asset to Risedle
Vault it only get yield from the leveraged tokens usage. If asset is inside Fuse,
it can be used for any other use cases. For exampple, Risedle can create two
products "gOHMRISE" (2x Long gOHM) and "SLPRISE" (leveraged Sushi LP) using the
same USDC on the pool without taking too much risk (guarded by Fuse liquidator).

### Strong ecosystem

Fuse allows Risedle to easily tap on large liquidity pools. Fuse also make it easy
for Risedle to partnership with other protocol since it only matter of adding
asset to the pool or plugging the Fuse Leveraged Token contract to the existing
Fuse pools.

## FLT: The Basics

Fuse Leveraged Tokens is ERC-20 that backed by collateral and the debt.

User can mint and redeem the fuse leveraged tokens. We will explain the details about
how mint and redemption process works below.

### Mint

[![](https://mermaid.ink/img/pako:eNptkc9uwjAMh1_FynWwB8iBwwbsMjSJbdIOvXiJaSPSpMsfKoR49zm03ZDAp0j-8vnn5CSU1ySkiPSTySlaGqwDtpUDrs9IYb5YrF8_JGyMS9Cb1IDy1mKigHaguM3Qw1tAZUnCC6UrBLpgFA3gQMwLfFE-36VG3XL1JWFtMTYQe-xupnL_nunascVgYJ0jh1pS56NJgNbemP6w-bTrkw_B9xATfluKt7G21OERUkOwKwFLvkfQPjMNqiG1Jw05GleDv6z8byiK8qrFocgcCCwdOErNN5LfkxunTSVmoqXQotH8R6fSqwTPbakSko-adphtqkTlzozmTvNiK22SD0Lu0EaaCczJvx-dEjKFTBM0_vNInX8By_SpGQ)](https://mermaid.live/edit/#pako:eNptkc9uwjAMh1_FynWwB8iBwwbsMjSJbdIOvXiJaSPSpMsfKoR49zm03ZDAp0j-8vnn5CSU1ySkiPSTySlaGqwDtpUDrs9IYb5YrF8_JGyMS9Cb1IDy1mKigHaguM3Qw1tAZUnCC6UrBLpgFA3gQMwLfFE-36VG3XL1JWFtMTYQe-xupnL_nunascVgYJ0jh1pS56NJgNbemP6w-bTrkw_B9xATfluKt7G21OERUkOwKwFLvkfQPjMNqiG1Jw05GleDv6z8byiK8qrFocgcCCwdOErNN5LfkxunTSVmoqXQotH8R6fSqwTPbakSko-adphtqkTlzozmTvNiK22SD0Lu0EaaCczJvx-dEjKFTBM0_vNInX8By_SpGQ)

The minting procedures:

1. Set `x` as the amount of collateral deposited by the user
1. Set `lr` as the current leverage ratio of the leveraged token
1. Set `p` as the current price of the collateral
1. Set `nav` as the current net-asset value of the leveraged tokens
1. Set `s` as the maximum slippage
1. Set `fa = (x*lr) - x` as the amount need to the flashswapped via DEX
1. Set `t = fa + x` as total collateral
1. Initiate flashswap `fa` amount to dex
1. Set `ra` as the required amount of stable to be paid to DEX
1. Deposit `t` to Rari Fuse
1. Borrow `y = (p * fa) + (p*fa*s)` amount of stables from Rari Fuse
1. If `y >= ra`, repay the flashswap with `ra` amount of stable and send back `y - ra != 0` to Rari Fuse
1. If `y < ra`, mint failed. Slippage too large.
1. Set `m = ((p*t) - ra) / nav` as minted amount of leveraged tokens
1. Mint `m` leveraged tokens to the user

### Redemption

[![](https://mermaid.ink/img/pako:eNptkctuwjAQRX9l5G3JD3jBpkA3lSqRVurCm8G-UKuOk_pBhRD_XpuEpkj1ypLPnJk7PgvdGwgpIr4yvMbK8iFwpzyV8xYRmuVy8_wqaQsDdORwROADDKX-Ez6OYCEK9_ASWDtIekIi3TvHqbCOhmA1RnAkmgpfrY__UpNutX6X1H7z8FeWeoqJd25CCzPb2uvD3UxbDpY2OaImGPhE6QNksEuUo_WHyTWV_MLNLfU83yyt7epmqlHDHkH-Lq_yYiE6hI6tKZs910olSt8OSshyNdhzdkkJ5S8FzYMphWtjUx-E3LOLWAjOqW9PXguZQsYNmn5noi4_QI2Sfg)](https://mermaid.live/edit/#pako:eNptkctuwjAQRX9l5G3JD3jBpkA3lSqRVurCm8G-UKuOk_pBhRD_XpuEpkj1ypLPnJk7PgvdGwgpIr4yvMbK8iFwpzyV8xYRmuVy8_wqaQsDdORwROADDKX-Ez6OYCEK9_ASWDtIekIi3TvHqbCOhmA1RnAkmgpfrY__UpNutX6X1H7z8FeWeoqJd25CCzPb2uvD3UxbDpY2OaImGPhE6QNksEuUo_WHyTWV_MLNLfU83yyt7epmqlHDHkH-Lq_yYiE6hI6tKZs910olSt8OSshyNdhzdkkJ5S8FzYMphWtjUx-E3LOLWAjOqW9PXguZQsYNmn5noi4_QI2Sfg)

The redemption procedures:

1. Set `y` as the amount of leveraged tokens redeemed by the user
1. Set `p` as the current price of the collateral
1. Set `c` as total collateral that back `y` amount of leveraged tokens
1. Set `d` as total debt that back `y` amount of leveraged tokens
1. Set `s` as the maximum slippage
1. Set `mp = p - (p*s)` as the minimum stable to be received from the dex
1. Set `cs = d / mp` as the amount of collateral need to sold to repay the debt
1. Initiate swap collateral to stable: maximum amount out `cs`, target `d` stable amount to dex
1. If swap failed, slippage too large, redemption failed.
1. If swap succeed, set `ca` as the amount of collateral that sold
1. Repay `d` amount of stable to Rari Fuse
1. Sent `c - ca` amount of collateral back to the user
1. Burn `y` amount of leveraged tokens

### Rebalancing

The rebalancing procedures is very simple. Given max leverage ratio and min leverage ratio,

- If current leverage ratio is less than the min leverage ratio then leverage up
- If current leverage ratio is larger than the max leverage ratio then leverage down

Leverage up simply borrow more stable to bought more collateral, while leveraged down
is simply selling some collateral to repay the debt.

## Summary

Fuse Leveraged Tokens is very similar to [Risedle Leveraged Tokens v1](https://docs.risedle.com/),
but instead of using Risedle Vault as the source of liquidity it uses Rari Fuse.
