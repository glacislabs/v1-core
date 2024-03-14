FROM node:18

RUN update-ca-certificates
RUN mkdir foundry &&\
    cd foundry &&\
    curl -L https://foundry.paradigm.xyz | bash &&\
    . ~/.bashrc &&\
    foundryup