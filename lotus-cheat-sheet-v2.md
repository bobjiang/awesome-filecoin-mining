本文主要包含以下内容：

- 编译Lotus
- 启动节点（lotus daemon）
- 创建矿工钱包
- 初始化矿工
- 启动矿工

# 编译过程，可以参考或直接下载 `build-lotus.sh`

[build-lotus.sh](./scripts/build-lotus.sh)

**install dependencies**
```
sudo apt update
sudo apt install -y mesa-opencl-icd ocl-icd-opencl-dev gcc git bzr jq pkg-config curl
sudo apt upgrade -y
```
如果你在中国，go 和 rust的安装需要设置代码，请参考如下配置

**install Go from https://golang.org/doc/install**  
**download go-lang package**

`sudo tar -C /usr/local -xzf go1.14.7.linux-amd64.tar.gz`

https://github.com/goproxy/goproxy.cn/blob/master/README.zh-CN.md

**install Rust from https://www.rust-lang.org/tools/install**
`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -y | sh`

**setup rust source in China**

1. 进入当前用户的 .cargo 目录 cd ~/.cargo
2. 新建名字叫 config 的文件
3. 编辑 config 文件写入
```
[source.crates-io]
replace-with = 'tuna'
[source.tuna]
registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git" 
```

**set environment variables**
```
export BELLMAN_CPU_UTILIZATION=0.9
export FIL_PROOFS_MAXIMIZE_CACHING=1
export FIL_PROOFS_USE_GPU_COLUMN_BUILDER=1
export FIL_PROOFS_USE_GPU_TREE_BUILDER=1
```
**append these export commands to ~/.bashrc to set them when starting a new shell session**

**setup a 256GB swap file to avoid out-of-memory issues while mining if you only have 128GB RAM**
```
sudo fallocate -l 256G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```
**show current swap spaces and take note of the current highest priority**

`swapon --show`

**append the following line to /etc/fstab (ensure pri is set larger than the current highest level priority) and then reboot**

`/swapfile swap swap pri=50 0 0`

`sudo reboot`

**check a 256GB swap file exists and it has the highest priority**

`swapon --show`

## install or reinstall lotus

**clone lotus from GitHub and checkout ntwk-calibration**
```
cd ~ && git clone https://github.com/filecoin-project/lotus.git && cd lotus
git reset --hard && git fetch --all && git checkout ntwk-calibration
```
**set environment variables to build from source (without these lotus will still run but sealing will take considerably longer)**
```
export RUSTFLAGS="-C target-cpu=native -g"
export RUST_LOG=info
export FFI_BUILD_FROM_SOURCE=1
```
**make and install it**
```
make clean && make all
sudo make install
```
# 启动节点（lotus daemon）

启动节点的命令如下：

`lotus daemon`

该命令启动后，会自动开始同步区块链节点。根据当前区块链的高度，可能需要几个小时甚至几天时间来同步。一般上述命令会后台运行并捕获日志。可以用如下命令进行节点同步情况的检查：

`lotus sync status`

还可以通过检查节点的链接情况来进一步诊断，如

`lotus net peers | wc -l`

得到的结果为当前节点已经连接到的节点总数。

# 创建矿工钱包

Filecoin矿工钱包是用如下命令创建：

`lotus wallet new bls`

你会得到一个t3开头的钱包地址： `t3wywhxlpg7itgym3zhchlxtcypec3p4rq7jejak5v3oayizsa7n7kvocmppwnrcca5c2z55tuclhqq3ugq7da`

**注意：**请备份钱包私钥 - `lotus export t3wywhxlpg7itgym3zhchlxtcypec3p4rq7jejak5v3oayizsa7n7kvocmppwnrcca5c2z55tuclhqq3ugq7da`

得到钱包地址后，可以去水龙头（当前是测试网络，主网时需要自行购买FIL）申请测试FIL。[Space Race水龙头](https://spacerace.faucet.glif.io/)

# 初始化矿工

**注意：**之前编译过程已经下载的 proof 参数文件，记得存放在一个可靠的路径，在初始化和启动矿工都会用到该文件。

设置如下的参数

```
# 如果你在中国，需要设置下面第一个 gateway 参数
export IPFS_GATEWAY="https://proof-parameters.s3.cn-south-1.jdcloud-oss.com/ipfs/"
export FIL_PROOFS_PARAMETER_CACHE=/home/test/storage/filecoin-proof-parameters
```

设置好变量后，可以初始化矿工，大概需要5分钟左右。owner就是上面刚刚生成的钱包地址。

`lotus-miner init --no-local-storage --owner=$T3_ADDRESS --sector-size=32GiB`

# 启动矿工

矿工初始化完成后，可以通过浏览器来查看对应的矿工ID。如在浏览器中输入钱包地址就可以查看到。

接下来就可以启动矿工啦

`nohup lotus-miner run > ~/lotus-miner.log 2>&1 &`

启动完成后，有一些常用命令来进行检查。
如：
`lotus-miner info`

```
Miner: t015685
Sector Size: 32 GiB
Byte Power:   0 B / 8.5 PiB (0.0000%)
Actual Power: 0  / 8.92 Pi (0.0000%)
	Committed: 0 B
	Proving: 0 B
Below minimum power threshold, no blocks will be won
Deals: 0, 0 B
	Active: 0, 0 B (Verified: 0, 0 B)

Miner Balance: 0 FIL
	PreCommit:   0 FIL
	Pledge:      0 FIL
	Locked:      0 FIL
	Available:   0 FIL
Worker Balance: 99.99999896838888492 FIL
Market (Escrow):  0 FIL
Market (Locked):  0 FIL

Expected Seal Duration: 12h0m0s

Sectors:
	Total: 0
```

# 下一步

接下来还有很长的路要走，比如配置文件、集群搭建和配置、错误诊断和排查。
欢迎大家来一起贡献。
