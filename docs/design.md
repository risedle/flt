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

Fuse allows Risedle to tap on large liquidity pools. Fuse also make it easy
for Risedle to partnership with other protocol since it only matter of adding
asset to the pool or plugging the Fuse Leveraged Token contract to the existing
Fuse pools.

## FLT: The Basics

Fuse Leveraged Tokens is ERC-20 that backed by 2 `fToken`:

1. Collateral asset `fToken`
2. Borrowed asset `fToken`

User can mint and redeem the fuse leveraged tokens. We will explain the details about
how mint and redemption process works below.

### Mint

[![](https://mermaid.ink/img/pako:eNptkc9uwjAMh1_FynWwB8iBwwbsMjSJbdIOvXiJaSPSpMsfKoR49zm03ZDAp0j-8vnn5CSU1ySkiPSTySlaGqwDtpUDrs9IYb5YrF8_JGyMS9Cb1IDy1mKigHaguM3Qw1tAZUnCC6UrBLpgFA3gQMwLfFE-36VG3XL1JWFtMTYQe-xupnL_nunascVgYJ0jh1pS56NJgNbemP6w-bTrkw_B9xATfluKt7G21OERUkOwKwFLvkfQPjMNqiG1Jw05GleDv6z8byiK8qrFocgcCCwdOErNN5LfkxunTSVmoqXQotH8R6fSqwTPbakSko-adphtqkTlzozmTvNiK22SD0Lu0EaaCczJvx-dEjKFTBM0_vNInX8By_SpGQ)](https://mermaid.live/edit/#pako:eNptkc9uwjAMh1_FynWwB8iBwwbsMjSJbdIOvXiJaSPSpMsfKoR49zm03ZDAp0j-8vnn5CSU1ySkiPSTySlaGqwDtpUDrs9IYb5YrF8_JGyMS9Cb1IDy1mKigHaguM3Qw1tAZUnCC6UrBLpgFA3gQMwLfFE-36VG3XL1JWFtMTYQe-xupnL_nunascVgYJ0jh1pS56NJgNbemP6w-bTrkw_B9xATfluKt7G21OERUkOwKwFLvkfQPjMNqiG1Jw05GleDv6z8byiK8qrFocgcCCwdOErNN5LfkxunTSVmoqXQotH8R6fSqwTPbakSko-adphtqkTlzozmTvNiK22SD0Lu0EaaCczJvx-dEjKFTBM0_vNInX8By_SpGQ)

## Futures Plan

We would like to implement
