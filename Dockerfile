FROM node:18

RUN update-ca-certificates
RUN mkdir foundry &&\
    cd foundry &&\
    curl -L https://foundry.paradigm.xyz | bash &&\
    . ~/.bashrc &&\
    foundryup
RUN apt-get update && apt-get install -y apt-transport-https
RUN apt-get install -y lcov
