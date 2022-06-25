#!/bin/bash
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
(echo ${ROOT_PASS}; echo ${ROOT_PASS}) | passwd root

service ssh restart

sleep 5

binary="evmosd"
folder=".evmosd"
gitrep="https://github.com/tharsis/evmos"
gitfold="evmos"

############################### SYNC ###############################
SYNC(){
    if [[ -z `ps -o pid= -p $nodepid` ]]; then
        echo "************************************"
        echo "*** Node not working, restart... ***"
        echo "************************************"

        nohup $binary start > /dev/null 2>&1 & nodepid=`echo $!`
        echo "*** Node PID ***"
        echo $nodepid
        echo "****************"

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

        echo "*** Node PID ***"
        echo $nodepid
        echo "****************"
        echo $sync
        source $HOME/.bashrc
    fi
    echo "*** Your address ***"
    echo $address
    echo "********************"
    echo "*** Your valoper ***"
    echo $valoper
    echo "********************"
    echo "*** Date ***"
    date
    echo "************"
    source $HOME/.bashrc
}

WORK (){
while [[ $sync == false ]]; do
    sleep 5m
    echo "*** Date ***"
    date
    echo "************"
    SYNC
    sleep 20
    ############################### Rewards ###############################
    reward=`$binary query distribution rewards $address $valoper -o json | jq -r .rewards[].amount`
    reward=`printf "%.f \n" $reward`
    echo "**********************************"
    echo "*** Your reward $reward $DENOM ***"
    echo "**********************************"
    sleep 5
    if [[ `echo $reward` -gt 1000000000000000000 ]]; then
        echo "*****************************************"
        echo "*** Rewards discovered, collecting... ***"
        echo "*****************************************"
        yes $WALLET_PASS | $binary tx distribution withdraw-rewards $valoper --from $address --fees $CREATE_VALIDATOR_FEES$DENOM --commission -y
        reward=0
        sleep 5
    fi
    #######################################################################


    ############################### Self Bonded ###############################
    if [[ $SELF_BONDED == true ]]; then
        yes $WALLET_PASS | $binary tx staking delegate $valoper 7000000000000000000atevmos --from $address --chain-id $CHAIN_ID --fees $CREATE_VALIDATOR_FEES$DENOM -y
    fi
    ###########################################################################


    ############################### Getting out of jail ###############################
    jailed=`$binary query staking validator $valoper -o json | jq -r .jailed`
    while [[ $jailed == true ]]; do
        echo "*** Attention! Validator in jail, attempt to get out of jail will happen in 30 minutes ***"
        sleep 30m
        yes $WALLET_PASS | $binary tx slashing unjail --from $address --chain-id $CHAIN_ID -y
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

echo "*** Go version ***"
go version
echo "******************"
########################################################################


############################### Node setup ###############################
git clone $gitrep && cd $gitfold
echo $EVMOS_VER
sleep 5
git checkout $EVMOS_VER
make install
mv $HOME/go/bin/$binary /usr/local/bin/$binary

echo "*** Binary version ***"
$binary version
echo "**********************"
##########################################################################


############################### Export ENV ###############################
echo 'export ROOT_PASS='${ROOT_PASS} >> $HOME/.bashrc
echo 'export MONIKER='${MONIKER} >> $HOME/.bashrc
echo 'export MNEMONIC='${MNEMONIC} >> $HOME/.bashrc
echo 'export WALLET_NAME='${WALLET_NAME} >> $HOME/.bashrc
echo 'export WALLET_PASS='${WALLET_PASS} >> $HOME/.bashrc
echo 'export SNAPSHOT_LINK='${SNAPSHOT_LINK} >> $HOME/.bashrc
echo 'export SYNC_RPC='${SYNC_RPC} >> $HOME/.bashrc
echo 'export LINK_KEY='${LINK_KEY} >> $HOME/.bashrc

sleep 5
source $HOME/.bashrc

echo "*** Binary version ***"
$binary version --long | head
echo "**********************"
sleep 10
##########################################################################


############################### ADDRBOOK ###############################
if [ -n "$ADDRBOOK" ]; then
    rm $HOME/$folder/config/addrbook.json
    wget -O $HOME/$folder/config/addrbook.json $ADDRBOOK
fi
########################################################################


############################### Genesis or Node initilization ###############################
echo "*** Initilization... ***"
$binary config chain-id $CHAIN_ID
$binary config keyring-backend os

sleep 10

$binary init "$MONIKER" --chain-id $CHAIN_ID

sleep 10

if [ -n "$GENESIS" ]; then
    wget -O $HOME/genesis.zip $GENESIS
    unzip $HOME/genesis.zip -d $HOME
    sha256sum $HOME/genesis.json
    mv $HOME/genesis.json $HOME/$folder/config/genesis.json
    rm $HOME/genesis.zip
fi

echo "*** NODE INIT ***"
sleep 10
#############################################################################################


############################### Add wallet ###############################
(echo "$MNEMONIC"; yes $WALLET_PASS) | $binary keys add ${WALLET_NAME} --recover
address=`yes $WALLET_PASS | $binary keys show $WALLET_NAME -a`
valoper=`yes $WALLET_PASS | $binary keys show $WALLET_NAME --bech val -a`

echo "*** Your address ***"
echo $address
echo "********************"
echo "*** Your valoper ***"
echo $valoper
echo "********************"
##########################################################################


############################### priv_validator_key ###############################
source $HOME/.bashrc
##################################################################################


############################### CONFIG ###############################
sleep 10
sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0$DENOM\"/;" $HOME/$folder/config/app.toml

pruning="custom" && \
pruning_keep_recent="100" && \
pruning_keep_every="0" && \
pruning_interval="10" && \
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/$folder/config/app.toml && \
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/$folder/config/app.toml && \
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/$folder/config/app.toml && \
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/$folder/config/app.toml

if [ -n "$PEERS" ]; then
    peers="$PEERS"
    sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/$folder/config/config.toml
fi

if [ -n "$SEEDS" ]; then
    seeds="$SEEDS"
    sed -i "s/seeds = \"\"/seeds = \"$seeds\"/" $HOME/$folder/config/config.toml
fi

indexer="null" && \
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/$folder/config/config.toml

snapshot_interval="0" && \
sed -i.bak -e "s/^snapshot-interval *=.*/snapshot-interval = \"$snapshot_interval\"/" $HOME/$folder/config/app.toml

if [ -n "$MINIMUM_GAS_PRICES" ]; then
    minimum_gas_prices="$MINIMUM_GAS_PRICES$DENOM" && \
    sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"$minimum_gas_prices\"/" $HOME/$folder/config/app.toml
fi
######################################################################


############################### Snapshot ###############################
if [[ -n $SNAPSHOT_LINK ]]; then
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


############################### SYNC RPC ###############################
if [[ -n $SYNC_RPC ]]; then
    echo "*** State-Sync Server ***"
    LATEST_HEIGHT=$(curl -s $SYNC_RPC/block | jq -r .result.block.header.height); \
    BLOCK_HEIGHT=$((LATEST_HEIGHT - 10000)); \
    TRUST_HASH=$(curl -s "$SYNC_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

    echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

    sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
    s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SYNC_RPC,$SYNC_RPC\"| ; \
    s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
    s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
    s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $HOME/$folder/config/config.toml
    sleep 5
fi

source $HOME/.bashrc
###################################################################


############################### NODE RUN ###############################
echo "*** Run node... ***"
nohup $binary start > /dev/null 2>&1 & nodepid=`echo $!`

echo "*** Node PID ***"
echo $nodepid
echo "****************"

source $HOME/.bashrc
echo "*** Node runing ! ***"

sleep 20
sync=`curl -s localhost:26657/status | jq .result.sync_info.catching_up`
echo $sync
if [[ $sync == true ]]; then
    echo "*************************"
    echo "*** Node is not sync! ***"
    echo "*************************"
fi
sleep 2

source $HOME/.bashrc
########################################################################


############################### Node is not synchronized ###############################
while [[ $sync == true ]]; do
    sleep 5m
    date
    echo "*************************"
    echo "*** Node is not sync! ***"
    echo "*************************"
    SYNC
done

############################### Node synchronized ###############################
while [[ $sync == false ]]; do
    sleep 5m
    echo "*** Date ***"
    date
    echo "************"

    echo "***************************************"
    echo "*** Node synchronized successfully! ***"
    echo "***************************************"
    SYNC

    val=`$binary query staking validator $valoper -o json | jq -r .description.moniker`
    echo $val
    sync=`curl -s localhost:26657/status | jq .result.sync_info.catching_up`
    echo $sync
    source $HOME/.bashrc

    if [[ -z "$val" ]]; then
        echo "*** Creating a validator... ***"
        yes $WALLET_PASS | $binary tx staking create-validator -y \
            --amount="1000000000000$DENOM" \
            --pubkey=$($binary tendermint show-validator) \
            --moniker="$MONIKER" \
            --website "https://validator.cipherdogs.net/" \
            --details "Cyber-crypto team. Decentralization and Distribution." \
            --chain-id="$CHAIN_ID" \
            --commission-rate="0.10" \
            --commission-max-rate="0.20" \
            --commission-max-change-rate="0.01" \
            --min-self-delegation="1000000" \
            --gas="$CREATE_VALIDATOR_GAS" \
            --fees="$CREATE_VALIDATOR_FEES$DENOM" \
            --from="$address"
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
