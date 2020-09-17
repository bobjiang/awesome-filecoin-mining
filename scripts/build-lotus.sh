#!/bin/bash

# 注意 filecoin-proof-parameters 文件大概有200多G，可以提前下载准备好，否则编译过程非常痛苦。
LOTUS_HOME=<your lotus home path>

export IPFS_GATEWAY="https://proof-parameters.s3.cn-south-1.jdcloud-oss.com/ipfs/" 
export FIL_PROOFS_PARAMETER_CACHE=/<your path>/filecoin-proof-parameters

date
echo "Begin to build lotus."
# prepare dependency
sudo apt update -y
sudo apt install -y mesa-opencl-icd ocl-icd-opencl-dev gcc git bzr jq pkg-config curl
sudo apt upgrade -y

# install go > 1.14
[ -z "$GOROOT" ] && GOROOT="$HOME/.go"

if [ ! -d "$GOROOT" ]; then

	echo "Downloading go package"
	wget --quiet https://golang.google.cn/dl/go1.14.7.linux-amd64.tar.gz

	mkdir -p "$GOROOT"
	echo "extracting package"
	sudo tar -C /usr/local -xzf go1.14.7.linux-amd64.tar.gz
	export PATH=$PATH:/usr/local/go/bin

	# setup go proxy in China
	# https://github.com/goproxy/goproxy.cn/blob/master/README.zh-CN.md

	go env -w GO111MODULE=on
	go env -w GOPROXY=https://goproxy.cn,direct

	rm -f go1.14.7.linux-amd64.tar.gz

fi

# install Rust from https://www.rust-lang.org/tools/install
[ -z "$RUSTROOT" ] && RUSTROOT="$HOME/.cargo"
if [ ! -d "$RUSTROOT" ]; then

	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
	# setup rust source in China
	# 1. 进入当前用户的 .cargo 目录 cd ~/.cargo
	# 2. 新建名字叫 config 的文件
	# 3. 编辑 config 文件写入
	# [source.crates-io]
	# replace-with = 'tuna'
	# [source.tuna]
	# registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git" 

	echo "[source.crates-io]
	replace-with = 'tuna'
	[source.tuna]
	registry = \"https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git\"
	" > ~/.cargo/config
fi

source ~/.profile

cd $LOTUS_HOME
# clone github repo
git clone https://github.com/filecoin-project/lotus.git
# current tag == v0.7.0
# 注意：需要检查最新的版本，请检查github代码仓库
# https://github.com/filecoin-project/lotus

git checkout v0.7.0

cd lotus
# if use AMD cpu, build the Filecoin proofs natively

env env RUSTFLAGS="-C target-cpu=native -g" FFI_BUILD_FROM_SOURCE=1 make clean deps all
# if command 'go' is not found, try adding /usr/local/go/bin to secure_path in /etc/sudoers
sudo make install

date
echo "End to build lotus."

