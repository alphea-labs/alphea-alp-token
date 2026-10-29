# ALPHEA ALP token

Audit scope: `src/alp/ALPToken.sol` only. `test/alp/ALPToken.t.sol` is its test suite. The design
record is `docs/adr/0004-plain-alp-token-and-revocable-team-vesting.md`; only its token part is
implemented, and the vesting it describes is not part of this repository or this audit.

`ALPToken` is a plain OpenZeppelin `ERC20` (BEP-20 on BNB Smart Chain). Its constructor mints the
entire fixed supply once to the treasury. It has no mint, burn, owner, role, pause, blacklist, fee,
transfer limit or upgrade path. Name, symbol, total supply and treasury are constructor arguments.

## Toolchain

- Solidity `0.8.28`, EVM `cancun`, optimizer on with 10,000 runs, `bytecode_hash = "none"`,
  `cbor_metadata = false`
- Foundry `v1.7.1`
- OpenZeppelin Contracts `5.4.0` at `c64a1edb67b6e3f4a15cca8909c9482ad33a02b0`
- forge-std `1.10.0` at `8bbcf6e3f8f62f419e5429a0bd89331c85c37824` (tests only)

## Build and test

```sh
git submodule update --init
forge fmt --check
forge build
FOUNDRY_PROFILE=ci forge test
```

## Provenance

This tree is exported from the ALPHEA contracts repository at commit
`2de100661d8a6694f9ce71ad17af4e413a460422`. The source, test, licence and design-record files are
byte-identical to that commit. With the settings above, `ALPToken` compiles to creation-code
keccak256 `0x0159f3793d990ba0d89afd78ba03b465bafac4dd7105101499b0a5f33ba3e2bb` and runtime-code
keccak256 `0x5b6d690ac9a5d80cd62caa137615a3308658a7376fc647ace6e4855530d22fd4`.
