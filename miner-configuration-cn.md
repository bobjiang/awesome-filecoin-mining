---
title: 'Lotus Miner配置文件详解'
description: '本文详细描述了lotus中的配置文件中的选项，以及每个选项的含义。'
---

# Lotus Miner配置文件详解

本文描述了 Lotus 配置文件，以及其中每个参数的具体含义。

Lotus Miner 配置文件在矿工初始化后创建的，存储于 `~/.lotusminer/config.toml` or `$LOTUS_MINER_PATH/config.toml` 。

默认所有的选项都被注释掉了，因此需要自定义的话可以去掉每行前面的 `# ` 。

::: tip
配置文件的修改要生效的话，需要重启 miner 
:::

[[TOC]]

## API section

API部分描述了矿工的API设置：

```toml
[API]
  # miner API 绑定地址
  ListenAddress = "/ip4/127.0.0.1/tcp/2345/http"
  # 这里是API地址的外部IP地址。
  RemoteListenAddress = "127.0.0.1:2345"
  # 网络超时的时间
  Timeout = "30s"
```

默认API地址是绑定本地的 loopback 地址 （即127.0.0.1）。如果想要其他机器访问API，需要设置对外网络的IP地址，或者 `0.0.0.0` (代表所有网络接口). 注意API的访问被 JWT tokens保护，所以需要设置 token。

将 `RemoteListenAddress` 配置为另一个节点连接miner时要使用的此值。通常是miner的IP地址和API端口，但是具体取决于你的环境（比如代理，公共IP等）。

## Libp2p section

这部分配置miner内嵌的 libp2p 节点。这部分最重要的是配置miner的公共IP以及固定端口：

```toml
# 绑定 libp2p主机的IP地址。0代表随机端口。
[Libp2p]
  ListenAddresses = ["/ip4/0.0.0.0/tcp/0", "/ip6/::/tcp/0"]
  # 填写你想要其他节点连接的地址（你的节点IP地址）
  AnnounceAddresses = []
  # 填写不想公开的节点地址。
  NoAnnounceAddresses = []
  # 连接管理的设置，如果机器连接数太多，适当降低数字。
  ConnMgrLow = 150
  ConnMgrHigh = 180
  ConnMgrGrace = "20s"
```

如果连接的数字超过 `ConnMgrHigh` 的定义，将减少当前的连接数直到达到设定的 `ConnMgrLow`。 最新的连接将被保持。

## Pubsub section

这部分设置Pubsub配置. Pubsub 用来分发网络中的消息：

```toml
[Pubsub]
  # 通常不需要运行 bootstrapping 节点，因此设定为 false
  Bootstrapper = false
  # FIXME，待启用。
  RemoteTracer = ""
```

## Dealmaking section

这部分设置 存储订单和检索订单的参数：

```toml
[Dealmaking]
  # 启用时，miner可能接受在线（online）的订单
  ConsiderOnlineStorageDeals = true
  # 启用时，miner可能接受线下（offline）的订单
  ConsiderOfflineStorageDeals = true
  # 启用时，miner可能接受检索订单
  ConsiderOnlineRetrievalDeals = true
  # 启用时，miner可能接受线下的检索订单
  ConsiderOfflineRetrievalDeals = true
  # 创建订单时，拒绝的数据 CID 清单
  PieceCidBlocklist = []
  # 一个扇区封装的时长
  ExpectedSealDuration = "12h0m0s"
  # 只接受特定条件的订单（订单过滤器，jq语法）
  Filter = ""
```

`ExpectedSealDuration` 是封装花费时间的估算值，开始时间早于期望封装完成时间时，用来拒绝订单。

:::warning
`ExpectedSealDuration` 最终值应该等于 `(TIME_TO_SEAL_A_SECTOR + WaitDealsDelay) * 1.5`. 该等式确保miner不会太早提交扇区。
:::

订单过滤器基于特定的参数，修改 `Filter` 参数. 该参数在处理订单时作为脚本命令执行。如果过滤器返回0则接受交易，否则将拒绝交易。设定 `Filter` 为 `false` 拒绝所有订单，设定为`true` 接受所有订单。例如下面的过滤只接受特定地址的客户端的交易：

```sh
Filter = "jq -e '.Proposal.Client == \"t1nslxql4pck5pq7hddlzym3orxlx35wkepzjkm3i\" or .Proposal.Client == \"t1stghxhdp2w53dym2nz2jtbpk6ccd4l2lxgmezlq\" or .Proposal.Client == \"t1mcr5xkgv4jdl3rnz77outn6xbmygb55vdejgbfi\" or .Proposal.Client == \"t1qiqdbbmrdalbntnuapriirduvxu5ltsc5mhy7si\" '"
```

## Sealing section

这部分设定扇区封装行为的参数：

```toml
[Sealing]
  # 在任何给定时间开始封装之前，有多少扇区可以等待打包更多交易的上限。
  MaxWaitDealsSectors = 2
  # 同时封装扇区的上限值 (包含 pledges)
  MaxSealingSectors = 0
  # 同时封装扇区的上限值，但仅包含订单的扇区 (不包含pledge sectors)
  MaxSealingSectorsForDeals = 0
  # 开始封装前新创建的扇区等待订单的时间
  WaitDealsDelay = "1h0m0s"
```

## Storage section

存储扇区设置miner执行特定的封装动作。取决于配置和封装worker的用途，需要修改某些选项。

```toml
[Storage]
  # 同时获取扇区数据的扇区上限
  ParallelFetchLimit = 10
  # miner可以执行的封装步骤。通常会设置不同的worker进行指定的封装操作。
  AllowPreCommit1 = true
  AllowPreCommit2 = true
  AllowCommit = true
  AllowUnseal = true
```

## Fees section

费用部分允许设定提交到链上不同消息的gas上限：

```toml
[Fees]
  # 支付的最大费用
  MaxPreCommitGasFee = "0.05 FIL"
  MaxCommitGasFee = "0.05 FIL"
  # PoSt是一个高价值的操作，因此默认值较高。
  MaxWindowPoStGasFee = "50 FIL"
```

取决于网络拥堵情况，交易的基本费用可能上涨或下跌。gas limits 必须大于包含消息的基本费用。基本费用很高时，会导致较大的费用，也会很快烧光你的钱。因此miner通常会自动提交消息，小心这个部分的设置。
