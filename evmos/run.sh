#!/bin/bash
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
(echo ${ROOT_PASS}; echo ${ROOT_PASS}) | passwd root

service ssh restart
service nginx start

sleep 5

binary="evmosd"
folder=".evmosd"
denom="atevmos"
chain="evmos_9000-4"
gitrep="https://github.com/tharsis/evmos"
gitfold="evmos"

############################### Go setup ###############################
SYNC(){
    if [[ -z `ps -o pid= -p $nodepid` ]]
    then
        echo "************************************"
        echo "*** Node not working, restart... ***"
        echo "************************************"
        nohup $binary start > /dev/null 2>&1 & nodepid=`echo $!`
        echo $nodepid
        sleep 5
        curl -s localhost:26657/status
        sync=`curl -s localhost:26657/status | jq .result.sync_info.catching_up`
        echo $sync
        source $HOME/.bashrc
    else
        echo "*********************"
        echo "*** Node working! ***"
        echo "*********************"
        curl -s localhost:26657/status
        sync=`curl -s localhost:26657/status | jq .result.sync_info.catching_up`
        echo $nodepid
        echo $sync
        source $HOME/.bashrc
    fi
    echo "*** Your address ***"
    echo $address
    echo "********************"
    echo "*** Your valoper ***"
    echo $valoper
    echo "********************"
    date
    source $HOME/.bashrc
}

WORK (){
while [[ $sync == false ]]
do        
    sleep 5m
    date
    SYNC
    sleep 20
    ############################### Rewards ###############################
    reward=`$binary query distribution rewards $address $valoper -o json | jq -r .rewards[].amount`
    reward=`printf "%.f \n" $reward`
    echo "**********************************"
    echo "*** Your reward $reward $denom ***"
    echo "**********************************"
    sleep 5
    if [[ `echo $reward` -gt 1000000 ]]
    then
        echo "*****************************************"
        echo "*** Rewards discovered, collecting... ***"
        echo "*****************************************"
        #(echo ${WALLET_PASS}) | $binary tx distribution withdraw-rewards $valoper --from $address --fees 5555$denom --commission -y
        #reward=0
        sleep 5
    fi
    #######################################################################

    ############################### Getting out of jail ###############################
    jailed=`$binary query staking validator $valoper -o json | jq -r .jailed`
    while [[ $jailed == true ]] 
    do
        echo "*** Attention! Validator in jail, attempt to get out of jail will happen in 30 minutes ***"
        sleep 30m
        (echo ${WALLET_PASS}) | $binary tx slashing unjail --from $address --chain-id $chain -y
        sleep 10
        jailed=`$binary query staking validator $valoper -o json | jq -r .jailed`
    done
    ###################################################################################
done
}

############################### Go setup ###############################
ver="1.18.1" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
source $HOME/.bash_profile && \

go version
########################################################################

############################### Node setup ###############################
git clone $gitrep && cd $gitfold
echo $EVMOS_VER
sleep 5
git checkout $EVMOS_VER
make install
mv ~/go/bin/$binary /usr/local/bin/$binary

$binary version
##########################################################################

############################### Export ENV ###############################
echo 'export ROOT_PASS='${ROOT_PASS} >> $HOME/.bashrc
echo 'export MONIKER='${MONIKER} >> $HOME/.bashrc
echo 'export MNEMONIC='${MNEMONIC} >> $HOME/.bashrc
echo 'export WALLET_NAME='${WALLET_NAME} >> $HOME/.bashrc
echo 'export WALLET_PASS='${WALLET_PASS} >> $HOME/.bashrc
echo 'export SNAPSHOT_LINK='${SNAPSHOT_LINK} >> $HOME/.bashrc
echo 'export SNAP_RPC='${SNAP_RPC} >> $HOME/.bashrc
echo 'export LINK_KEY='${LINK_KEY} >> $HOME/.bashrc

sleep 5
source $HOME/.bashrc

$binary version --long | head
sleep 10
##########################################################################

############################### Node initilization ###############################
echo "*** NODE INIT ***"
$binary init "$MONIKER" --chain-id $chain
sleep 10
##################################################################################

############################### Add wallet ###############################
(echo "${MNEMONIC}"; echo ${WALLET_PASS}; echo ${WALLET_PASS}) | $binary keys add ${WALLET_NAME} --recover
address=`(echo ${WALLET_PASS}) | $(which $binary) keys show $WALLET_NAME -a`
valoper=`(echo ${WALLET_PASS}) | $(which $binary) keys show $WALLET_NAME --bech val -a`

echo "*** Your address ***"
echo $address
echo "********************"
echo "*** Your valoper ***"
echo $valoper
echo "********************"
##########################################################################

############################### Genesis ###############################
if [ -n "$GENESIS" ]; then
    wget -O $HOME/genesis.zip $GENESIS
    unzip $HOME/genesis.zip -d $HOME
    sha256sum $HOME/genesis.json
    mv $HOME/genesis.json $HOME/$folder/config/genesis.json
    rm $HOME/genesis.zip
fi

if [ -n "$ADDRBOOK" ]; then
    rm $HOME/$folder/config/addrbook.json
    wget -O $HOME/$folder/config/addrbook.json $ADDRBOOK
fi
#######################################################################

############################### priv_validator_key ###############################
source $HOME/.bashrc

$binary config chain-id $chain

$binary config keyring-backend os
##################################################################################

############################### MINIMUM GAS PRICES ###############################
sleep 10
sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0$denom\"/;" ~/$folder/config/app.toml

pruning="custom" && \
pruning_keep_recent="100" && \
pruning_keep_every="0" && \
pruning_interval="50" && \
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/$folder/config/app.toml && \
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/$folder/config/app.toml && \
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/$folder/config/app.toml && \
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/$folder/config/app.toml

peers="$PEER"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/$folder/config/config.toml

indexer="null" && \
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/$folder/config/config.toml

snapshot_interval="0" && \
sed -i.bak -e "s/^snapshot-interval *=.*/snapshot-interval = \"$snapshot_interval\"/" ~/$folder/config/app.toml
##################################################################################

############################### Snapshot ###############################
if [[ -n $SNAPSHOT_LINK ]]
then
    cd /root/$folder/
    wget -O snap.tar $SNAPSHOT_LINK
    tar xvf snap.tar 
    rm snap.tar
    echo "************************"
    echo "*** Snapshot loaded! ***"
    echo "************************"
    cd /
fi

source $HOME/.bashrc
########################################################################


############################### RPC ###############################
if [[ -n $SNAP_RPC ]]
then

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 10000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $HOME/$folder/config/config.toml
echo RPC
sleep 5
fi

source $HOME/.bashrc
###################################################################


############################### NODE RUN ###############################
echo "*** Run node... ***"
nohup $binary start > /dev/null 2>&1 & nodepid=`echo $!`
echo $nodepid
source $HOME/.bashrc
echo "*** Node runing ! ***"
sleep 20
sync=`curl -s localhost:26657/status | jq .result.sync_info.catching_up`
echo $sync
sleep 2

source $HOME/.bashrc

############################### Node is not synchronized ###############################
while [[ $sync == true ]]
do
    sleep 5m
    date
    echo "*************************"
    echo "*** Node is not sync! ***"
    echo "*************************"
    SYNC
    
done

############################### Node synchronized ###############################
while [[ $sync == false ]]
do     
    sleep 5m
    date
    echo "***************************************"
    echo "*** Node synchronized successfully! ***"
    echo "***************************************"
    SYNC
    val=`$binary query staking validator $valoper -o json | jq -r .description.moniker`
    echo $val
    sync=`curl -s localhost:26657/status | jq .result.sync_info.catching_up`
    echo $sync
    source $HOME/.bashrc
    if [[ -z "$val" ]]
    then
        echo "*** Creating a validator... ***"
        (echo ${WALLET_PASS}) | $binary tx staking create-validator --amount="1000000000000$denom" --pubkey=$($binary tendermint show-validator) --moniker="$MONIKER" --chain-id="$chain" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1000000" --gas="auto" --gas-price="0.025$denom" --from="$address" -y
        echo 'true' >> /var/validator
        val=`$binary query staking validator $valoper -o json | jq -r .description.moniker`
        echo $val
    else
        val=`$binary query staking validator $valoper -o json | jq -r .description.moniker`
        echo $val
        MONIKER=`echo $val`
        WORK
    fi
done