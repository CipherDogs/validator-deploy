FROM ubuntu:latest

RUN apt-get update && apt-get install -y \ 
    sudo \
    wget \
    curl \
    tar \
    zip \
    unzip \
    jq

RUN apt-get upgrade -y
RUN apt install ssh -y
RUN sudo apt update && sudo apt upgrade -y
RUN sudo apt install build-essential git make gcc nvme-cli pkg-config libssl-dev libleveldb-dev clang bsdmainutils ncdu libleveldb-dev -y

COPY ./run.sh ./
CMD bash run.sh