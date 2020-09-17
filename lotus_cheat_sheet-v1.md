# install dependencies
sudo apt update
sudo apt install -y mesa-opencl-icd ocl-icd-opencl-dev gcc git bzr jq pkg-config curl
sudo apt upgrade -y
# install Go from https://golang.org/doc/install
# install Rust from https://www.rust-lang.org/tools/install

# set environment variables
export BELLMAN_CPU_UTILIZATION=0.875
export FIL_PROOFS_MAXIMIZE_CACHING=1
export FIL_PROOFS_USE_GPU_COLUMN_BUILDER=1
export FIL_PROOFS_USE_GPU_TREE_BUILDER=1
# append these export commands to ~/.bashrc to set them when starting a new shell session

# setup a 256GB swap file to avoid out-of-memory issues while mining if you only have 128GB RAM
sudo fallocate -l 256G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
# show current swap spaces and take note of the current highest priority
swapon --show
# append the following line to /etc/fstab (ensure pri is set larger than the current highest level priority) and then reboot
# /swapfile swap swap pri=50 0 0
sudo reboot
# check a 256GB swap file exists and it has the highest priority
swapon --show

# install or reinstall lotus
sudo rm -rf ~/lotus ~/.lotus ~/.lotusminer /usr/local/bin/lotus*
# (optional) remove proof parameters (these files are very large and will take a long time to redownload)
sudo rm -rf /var/tmp/filecoin-proof-parameters
# clone lotus from GitHub and checkout ntwk-calibration
cd ~ && git clone https://github.com/filecoin-project/lotus.git && cd lotus
git reset --hard && git fetch --all && git checkout ntwk-calibration
# set environment variables to build from source (without these lotus will still run but sealing will take considerably longer)
export RUSTFLAGS="-C target-cpu=native -g"
export RUST_LOG=info
export FFI_BUILD_FROM_SOURCE=1
# make and install it
make all && sudo make install
# if command 'go' is not found, try adding /usr/local/go/bin to secure_path in /etc/sudoers
# you should see lots of rust related downloads, if not you're probably not building it from source

# start lotus daemon and connect to the lotus network
# see https://filscan.io/ for graphs, maps, and the current status of the network and miners
# check the open file limit and ensure it is set to at least 10000000
# consider adding ulimit -n 10000000 to ~/.bashrc to set it at the start of each bash session
ulimit -n
ulimit -n 10000000
# start lotus daemon in the background
lotus daemon > ~/lotus.log 2>&1 &
# wait for the chain to sync (this can take minutes, hours or even days depending on the height of the chain)
lotus sync wait
# check that the number of connected peers is at least 1
lotus net peers | wc -l
# update Libp2p ListenAddresses and Libp2p AnnounceAddresses in ~/.lotus/config.toml to the following:
#   ListenAddresses = ["/ip4/0.0.0.0/tcp/24001"]
#   AnnounceAddresses = ["/ip4/<YOUR_PUBLIC_IP_ADDRESS>/tcp/24001"]
# assign a static IP address to your machine on your local network
# log in to your home router and forward port 24001 to the previously assigned static IP address
# restart the daemon in the background so it continues running after closing the terminal
lotus daemon stop
nohup lotus daemon > ~/lotus.log 2>&1 &

# create a new bls wallet and miner
T3_ADDRESS=$(lotus wallet new bls) && echo $T3_ADDRESS
# assign funds to the t3 address using https://faucet.calibration.fildev.network
# see https://filecoin.io/blog/welcome-to-space-race/#participating-in-space-race for conditions on using the faucet
# initialize the miner (this will download and verify the ~108GB v28 proof parameters to /var/tmp/filecoin-proof-parameters)
lotus-miner init --no-local-storage --owner=$T3_ADDRESS --sector-size=32GiB
# update Libp2p ListenAddresses and Libp2p AnnounceAddresses in ~/.lotusminer/config.toml to the following:
#  ListenAddresses = ["/ip4/0.0.0.0/tcp/24002"]
#  AnnounceAddresses = ["/ip4/<YOUR_PUBLIC_IP_ADDRESS>/tcp/24002"]
# log in to your home router and forward port 24002 in the same way as was done for the lotus daemon
# start lotus-miner in the background, wait until it is ready (this can take a few minutes), and print the wallet balance
nohup lotus-miner run > ~/lotus-miner.log 2>&1 &
watch -n 5 lotus-miner info
lotus wallet balance $T3_ADDRESS

# check you are publically dialable
PUBLIC_IP=$(curl ifconfig.me) && echo $PUBLIC_IP
ping $PUBLIC_IP
telnet $PUBLIC_IP 24001
telnet $PUBLIC_IP 24002
lotus net reachability
# use https://www.yougetsignal.com/tools/open-ports/ to check ports 24001 and 24002 are open

# configure your miner
# check the listening address of your miner and set the on-chain record of it
LISTEN_ADDRESS=$(lotus-miner net listen) && echo $LISTEN_ADDRESS
lotus-miner actor set-addrs $LISTEN_ADDRESS
# set MaxSealingSectors in ~/.lotusminer/config.toml to the number of concurrent seal workers you want to run
# set storage locations for sealing storage (e.g., a fast SSD) and long term storage (e.g., a slow HDD)
# for seal I use ~/.lotusminer and store I use /media/<USERNAME>/<HDD_DEVICE_NAME>/filecoin
lotus-miner storage attach --init --seal <PATH_FOR_SEALING_STORAGE>
lotus-miner storage attach --init --store <PATH_FOR_LONG_TERM_STORAGE>
lotus-miner storage list
# check that the funds for sending the set-addrs message have been deducted from your wallet (this may take about 30 seconds)
watch -n 5 lotus wallet balance $T3_ADDRESS

# start sealing a sector
# pledge storage by packing random data to demonstrate capability of storing data without having to wait for deals
lotus-miner sectors pledge
# check the sealing job has started
lotus-miner sealing jobs
# check that a 32GiB (34.4GB) file has been created in <PATH_FOR_SEALING_STORAGE>/unsealed
# check sealing workers show 1 core in use
lotus-miner sealing workers
# wait for the sector to be created and show "0: PreCommit1 sSet: NO active: NO tktH: 0 seedH: 0 deals: [0]" (this will take a few minutes)
watch -n 5 lotus-miner sectors list
# check the sector file has been copied to <PATH_FOR_SEALING_STORAGE>/sealed
# wait for the sector to be sealed and show "0: Proving sSet: YES active: YES tktH: xxxx seedH: yyyy deals: [0]" (this will take several hours)
# view to log to determine how long the sealing process took on your machine
lotus-miner sectors status --log 0
# set ExpectedSealDuration accordingly (see configuring deal criteria below)
# after sealing is complete, mark the pledged sector for upgrade so it can start accepting deals (including those from the bot)
lotus-miner sectors mark-for-upgrade 0
# within 24 hours, active should change from YES to NO and will be visible on the dashboard
# there is a known bug where mark-for-upgrade sometimes gets ignored
# if more than 24 hours has passed consider calling mark-for-upgrade again, doing so will have no adverse effects
# check the sector file has been copied to <PATH_FOR_LONG_TERM_STORAGE>/sealed

# monitor sectors as they progress through each stage
# install and run htop to monitor CPU and memory usage
sudo apt install htop
htop
# in a separate terminal watch the lotusminer log for entries of the form "INFO storage_proofs_porep::stacked::vanilla::proof > generating layer"
watch tail -n 24 ~/lotus-miner.log
# TODO how many layers to expect?
# in a third terminal watch the status of the sector
watch -n 5 lotus-miner sectors status --log --on-chain-info 0
# the following log entries are what I observed my machine (Ryzen 9 3900X @ 3.8GHz, RTX 2080 Super, 128GB DDR4 RAM @ 3000MHz)
# ignore log entries 2 and 3, I restarted my machine due to an error unrelated to lotus
# PreCommit1 started at 01:49:28 so took 4h50 and used 1 CPU @ 100%
# TODO: perance when running 2 PC1 in parallel ? set MaxSealingSectors = 2
# the total sealing duration was 8h20
# --------
# Event Log:
# 0.	2020-08-20 22:40:47 +0000 UTC:	[event;sealing.SectorStartCC]	{"User":{"ID":0,"SectorType":3,"Pieces":[{"Piece":{"Size":34359738368,"PieceCID":{"/":"ba..."}},"DealInfo":null}]}}
# 1.	2020-08-20 22:40:47 +0000 UTC:	[event;sealing.SectorPacked]	{"User":{"FillerPieces":null}}
# 2.	2020-08-21 01:32:25 +0000 UTC:	[event;sealing.SectorRestart]	{"User":{}}
# 3.	2020-08-21 01:49:28 +0000 UTC:	[event;sealing.SectorRestart]	{"User":{}}
# 4.	2020-08-21 06:31:48 +0000 UTC:	[event;sealing.SectorPreCommit1]	{"User":{"PreCommit1Out":"ey...","TicketValue":"H3...","TicketEpoch":2234}}
# 5.	2020-08-21 07:04:18 +0000 UTC:	[event;sealing.SectorPreCommit2]	{"User":{"Sealed":{"/":"ba..."},"Unsealed":{"/":"ba..."}}}
# 6.	2020-08-21 07:04:18 +0000 UTC:	[event;sealing.SectorPreCommitted]	{"User":{"Message":{"/":"ba..."},"PreCommitDeposit":"1761729940027002722","PreCommitInfo":{"SealProof":3,"SectorNumber":0,"SealedCID":{"/":"ba..."},"SealRandEpoch":2234,"DealIDs":[],"Expiration":1557523,"ReplaceCapacity":false,"ReplaceSectorDeadline":0,"ReplaceSectorPartition":0,"ReplaceSectorNumber":0}}}
# 7.	2020-08-21 07:07:30 +0000 UTC:	[event;sealing.SectorPreCommitLanded]	{"User":{"TipSet":"AX..."}}
# 8.	2020-08-21 08:22:30 +0000 UTC:	[event;sealing.SectorSeedReady]	{"User":{"SeedValue":"di...","SeedEpoch":3915}}
# 9.	2020-08-21 10:06:56 +0000 UTC:	[event;sealing.SectorCommitted]	{"User":{"Message":{"/":"ba..."},"Proof":"md..."}}
# 10.	2020-08-21 10:10:30 +0000 UTC:	[event;sealing.SectorProving]	{"User":{}}
# 11.	2020-08-21 10:11:48 +0000 UTC:	[event;sealing.SectorFinalized]	{"User":{}}

# check proving
# a snark proof needs to be computed every 30 minutes and requires a high-end GPU or CPU
# use the following to monitor proof status and faults
lotus-miner proving info
lotus-miner proving deadlines
lotus-miner proving faults

# test your miner by making a storage and retrieval deal
# there are effectively two modes of retrieval (although at first only mode #1 will be used)
# 1. hot storage: store two copies of the data with one sealed copy being used for generating storage proofs and the other original copy for fast retrieval
# 2. cold storage: only store the sealed copy and require it to be unsealed first (a computational and time intensive task)
T0_ADDRESS=$(lotus-miner info | head -n 1 | cut -c 8-) && echo $T0_ADDRESS
lotus state miner-info $T0_ADDRESS
# create a new t1 address, add funds to it from the t3 address, and wait for the transaction to complete (this will take about a minute)
T1_ADDRESS=$(lotus wallet new) && echo $T1_ADDRESS
lotus send $T1_ADDRESS 20
watch -n 5 lotus wallet balance $T1_ADDRESS
# add a local file and copy the data CID
echo -e "Filecoin is a decentralized storage market - think of it like Airbnb for cloud storage - where anybody with extra hard drive space can sell it on the network.\n- Juan Benet" > ~/test_file_original.txt
lotus client import ~/test_file_original.txt
DATA_CID=<copy data CID beginning ba...>
# attempt to find the file it on the network (this should say LOCAL)
lotus client find $DATA_CID
# query your miner and make a deal at the default price and minimum duration
lotus client query-ask $T0_ADDRESS
DEAL_CID=$(lotus client deal $DATA_CID $T0_ADDRESS 0.0000000005 518400) && echo $DEAL_CID
lotus client list-deals
lotus client get-deal $DEAL_CID
# wait for the sector to be created
watch -n 5 lotus-miner sectors list
# check that a 32GiB (34.4GB) file has been created in <PATH_FOR_SEALING_STORAGE>/unsealed
# (optional) manually start sealing the sector to avoid waiting for the default seal delay
lotus-miner sectors seal <SECTOR_ID>
# start retrieving data from the storage miner
lotus client retrieve $DATA_CID ~/test_file_retrieved.txt
# view the status of the retrieval deal and wait for it to complete
watch -n 5 lotus-miner retrieval-deals list
# 
cat ~/test_file_retrieved.txt
# check miner info and move storage payments made to <T0_ADDRESS> into <T3_ADDRESS>
lotus-miner info
lotus-miner actor withdraw

# configuring deal criteria
# deals are automatically managed by the lotus-miner
# to configure the criteria for accepting deals edit the file ~/.lotusminer/config.toml
# ExpectedSealDuration (defaults to 12h0m0s) should be set according to how quickly you can seal a sector
# only deals starting after this delay will be accepted, at which point you must start providing proofs
# MaxPreCommitGasFee, MaxCommitGasFee, and MaxWindowPoStGasFee are set under [Fees]
# WaitDealsDelay (defaults to 1h0m0s) is the delay between accepting the first deal and starting the sealing process
# this allows multiple deals to be sealed in the same sector
# Filter is a shell command that decides which deals to accept (on returning exit code 0) or reject (any other exit code)
# here are some example Filter commands
# reject all deals:
#   Filter = false
# accept all deals (the default):
#   Filter = true
# accept/reject deals randomly:
#   Filter = (($RANDOM < 10000))
# only accept deals from specific addresses (during Space Race, consider setting these to the addresses of the bots to avoid malicious actors sending spam deals):
#   Filter = "jq -e '.Proposal.Client == \"t1...\" or .Proposal.Client == \"t1...\" '"

# check logs
tail -f ~/lotus.log
watch tail -n 24 ~/lotus-miner.log
grep -n error ~/lotus-miner.log

# import/export keys
lotus wallet import ~/<TX_ADDRESS>.keyinfo
lotus wallet export <TX_ADDRESS> > ~/<TX_ADDRESS>.keyinfo

# import/export chain
lotus daemon --import-chain --halt-after-import ~/filecoin_chain.car
lotus chain export ~/filecoin_chain.car
