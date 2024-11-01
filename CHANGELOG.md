# Changelog

## [0.1.2](https://github.com/SmarDex-Ecosystem/universal-router/compare/v0.1.1...v0.1.2) (2024-10-23)


### Features

* avoid `to` or `validator` to be the router address ([#50](https://github.com/SmarDex-Ecosystem/universal-router/issues/50)) ([69108d1](https://github.com/SmarDex-Ecosystem/universal-router/commit/69108d12e3d1a422793ef2eca0db25d3947686dd))
* sepolia deployment ([#48](https://github.com/SmarDex-Ecosystem/universal-router/issues/48)) ([681ad5b](https://github.com/SmarDex-Ecosystem/universal-router/commit/681ad5b95e91e75445bb1a7b8555a0e15003b92f))
* transferfrom command ([#40](https://github.com/SmarDex-Ecosystem/universal-router/issues/40)) ([49bbbdf](https://github.com/SmarDex-Ecosystem/universal-router/commit/49bbbdf7f3f7e6cf4a954e5568b0b8aa3b9f80c2))
* usdn router lib ([#46](https://github.com/SmarDex-Ecosystem/universal-router/issues/46)) ([2167548](https://github.com/SmarDex-Ecosystem/universal-router/commit/2167548283b3851cbc36fd12aed9dd713c8e65e0))
* usdn transferSharesFrom ([#41](https://github.com/SmarDex-Ecosystem/universal-router/issues/41)) ([411d0b2](https://github.com/SmarDex-Ecosystem/universal-router/commit/411d0b2625f1c22253b4e0dedf4e50672357f731))
* usdn-0.19.1 ([#44](https://github.com/SmarDex-Ecosystem/universal-router/issues/44)) ([d5c25e9](https://github.com/SmarDex-Ecosystem/universal-router/commit/d5c25e9261842ceec4fb750173d3a806e42874d6))
* usdn-0.20.0 ([#54](https://github.com/SmarDex-Ecosystem/universal-router/issues/54)) ([82d828d](https://github.com/SmarDex-Ecosystem/universal-router/commit/82d828d1b7bb837bac1a19c0348927c6054215f1))


### Bug Fixes

* cast ([#51](https://github.com/SmarDex-Ecosystem/universal-router/issues/51)) ([92502d9](https://github.com/SmarDex-Ecosystem/universal-router/commit/92502d9aea55838befb525ddb097f3cfc54f41ae))
* check address zero sweep ([#52](https://github.com/SmarDex-Ecosystem/universal-router/issues/52)) ([d3267e7](https://github.com/SmarDex-Ecosystem/universal-router/commit/d3267e797f819c507f29be9bbb74d2968e2bf682))
* liquidate ([#47](https://github.com/SmarDex-Ecosystem/universal-router/issues/47)) ([75beec2](https://github.com/SmarDex-Ecosystem/universal-router/commit/75beec27953a0ac86d032df9652fd2bf2f691e8b))

## [0.1.1](https://github.com/SmarDex-Ecosystem/universal-router/compare/v0.1.0...v0.1.1) (2024-07-17)


### Features

* add gas token limit in sweep ([#28](https://github.com/SmarDex-Ecosystem/universal-router/issues/28)) ([5a49a09](https://github.com/SmarDex-Ecosystem/universal-router/commit/5a49a09b7ba50d539b665a036de453f7d7532326))
* add permit (eip-2612) support ([#6](https://github.com/SmarDex-Ecosystem/universal-router/issues/6)) ([9ab38bd](https://github.com/SmarDex-Ecosystem/universal-router/commit/9ab38bd5f34be53acd15121140ae66b0a1783a2d))
* deployment script ([#29](https://github.com/SmarDex-Ecosystem/universal-router/issues/29)) ([b172ed7](https://github.com/SmarDex-Ecosystem/universal-router/commit/b172ed731906641804730b466ce33c4c6b45bea3))
* init contracts ([#1](https://github.com/SmarDex-Ecosystem/universal-router/issues/1)) ([16f7676](https://github.com/SmarDex-Ecosystem/universal-router/commit/16f767649a962aa0af61bb3a502f7eadca5fef75))
* liquidation ([#10](https://github.com/SmarDex-Ecosystem/universal-router/issues/10)) ([6ba87a3](https://github.com/SmarDex-Ecosystem/universal-router/commit/6ba87a3d5784659f855c77fdbc9bd86f8baf909e))
* path lib length check ([#22](https://github.com/SmarDex-Ecosystem/universal-router/issues/22)) ([33c89ed](https://github.com/SmarDex-Ecosystem/universal-router/commit/33c89ed7629cb2114d1c2ec012ce2ea5060f9b6b))
* permit2 transferfrom batch ([#20](https://github.com/SmarDex-Ecosystem/universal-router/issues/20)) ([c518ff8](https://github.com/SmarDex-Ecosystem/universal-router/commit/c518ff8425af6255ad6ec43377bbc6ee39a35211))
* rebalancer initiateDeposit ([#30](https://github.com/SmarDex-Ecosystem/universal-router/issues/30)) ([345ccbd](https://github.com/SmarDex-Ecosystem/universal-router/commit/345ccbdb2af4316d9e7a151641c54e11db3781eb))
* smardex exact in ([#13](https://github.com/SmarDex-Ecosystem/universal-router/issues/13)) ([2c1ae85](https://github.com/SmarDex-Ecosystem/universal-router/commit/2c1ae8569abfd462dd955af29aa9e81be95af16f))
* smardex exact out ([#15](https://github.com/SmarDex-Ecosystem/universal-router/issues/15)) ([5ef4d46](https://github.com/SmarDex-Ecosystem/universal-router/commit/5ef4d4676021e046e6c2a564a35d42ef1b55f5d1))
* smardex lib ([#19](https://github.com/SmarDex-Ecosystem/universal-router/issues/19)) ([7e13809](https://github.com/SmarDex-Ecosystem/universal-router/commit/7e1380983c53c3e167f53d33321727adaa781605))
* validate close position ([#8](https://github.com/SmarDex-Ecosystem/universal-router/issues/8)) ([068966b](https://github.com/SmarDex-Ecosystem/universal-router/commit/068966b29d3ee8d234ea06bf93e71e2156267190))
* validate pending actions ([#7](https://github.com/SmarDex-Ecosystem/universal-router/issues/7)) ([9963f5b](https://github.com/SmarDex-Ecosystem/universal-router/commit/9963f5b5f7719480f94caea035fd565b476d4d59))
* wusdn ([#12](https://github.com/SmarDex-Ecosystem/universal-router/issues/12)) ([6542663](https://github.com/SmarDex-Ecosystem/universal-router/commit/6542663620ff5a2b0849fac96d97f32040b0fe28))


### Bug Fixes

* ci ([#3](https://github.com/SmarDex-Ecosystem/universal-router/issues/3)) ([1e76e95](https://github.com/SmarDex-Ecosystem/universal-router/commit/1e76e95688d2cb71bf421d3a05fbc61ae26896ef))
* imports ([2782704](https://github.com/SmarDex-Ecosystem/universal-router/commit/278270435e0fc9d0d53c9aa3f0e890dd7ff959a9))
* usdn imports ([#21](https://github.com/SmarDex-Ecosystem/universal-router/issues/21)) ([6684727](https://github.com/SmarDex-Ecosystem/universal-router/commit/6684727838bf115270d57dbea53069ce46a84b67))
* use new setup ([#26](https://github.com/SmarDex-Ecosystem/universal-router/issues/26)) ([30f1959](https://github.com/SmarDex-Ecosystem/universal-router/commit/30f1959694f0b074855be3c413908af7b24b5d61))
