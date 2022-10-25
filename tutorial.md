---
title: Providing an Ethereum endpoint 
description: 
author: "Mario Havel"
tags: ["clients", "geth", "nodes", "hosting", "provider"]
skill: intermediate
lang: en
sidebar: true
published: 
---

Ethereum client gives you direct access to data in the Ethereum network and allows you to interact with it. There are [many services](https://ethereum.org/en/developers/docs/nodes-and-clients/nodes-as-a-service/) that provide public free or paid access to Ethereum client JSON-RPC. This tutorial will explain how to securely provide your own public endpoint for Ethereum clients. 

## Prerequisties {#prerequisites}

This tutorial assumes you are familiar with running your own Ethereum client, understand its API endpoints and how to use them. 

Check out [Run a node](https://ethereum.org/en/run-a-node/), [Nodes and clients](https://ethereum.org/en/developers/docs/nodes-and-clients/), and [JSON-RPC](https://ethereum.org/en/developers/docs/apis/json-rpc/) for more information. 

## Intro to the stack {#intro}

As an Ethereum user, developer, or service provider, you can setup your own instance of the Ethereum client to use Ethereum in more secure, private and trustless way. Using Ethereum directly without relying on third parties is always the recommended approach. 
If you spun client on your own machine, you might need to access it from anywhere, not just locally on machine where it's running. 

This tutorial will guide you through the setup of tools for creating a public endpoint which serves as a proxy, filter, and also a balancer for your Ethereum clients.

![](https://storage.googleapis.com/ethereum-hackmd/upload_7e826722686d2a509a22663de52db3d3.png)

The software stack explained in this tutorial. 

Setup in this tutorial will result in multiple connected services handling the RPC data:
* End users (a wallet, Ethereum application) can securely connect to an adress via https.
* Their requests are handled by Nginx which proxys them to a Dshackle instance.
* [Dshackle](https://github.com/emeraldpay/dshackle) filters and balances requests to chosen endpoints with the Ethereum execution client's RPC.

## Client configuration {#client-config}

Let's start with proper configuration of your Ethereum client software. User facing RPC endpoint is served by an execution layer client. All clients can serve their JSON-RPC endpoint reachable via http or websockets. This can be enabled in the client's configuration. The default port where RPC is bound is 8545. Ports and addresses can also be configured for your needs, for example, if you are running multiple clients at the same machine.

Client configuration also allows choosing which namespaces or methods are allowed. For security reasons, disable at least `admin` namespace. If your node is not in archive mode, it's also discouraged to allow `debug`. However, filtering and enabling only specified calls can be done later with Dshackle. 

Each client handles configuration differently with various syntaxes and defualts. For details, refer to the documentation of the chosen client. Here are general examples of basic configurtion of various execution client to enable http and websockets RPC, specify a port and enabled namespaces:

```
geth --http --http.port 8552 --http.corsdomain "*" --http.api web3,eth,txpool,net,debug --ws --ws.api web3,eth,txpool,net,debug

erigon --http --http.port 8545 --http.corsdomain "*" --ws --http.api web3,eth,txpool,net,debug,admin,trace,erigon 

besu --rpc-http-enabled=true --rpc-http-apis=ADMIN,DEBUG,ETH,NET,TRACE,TXPOOL,WEB3 --rpc-http-port=8545 --rpc-http-cors-origins=* --host-allowlist=* --rpc-ws-enabled=true --rpc-ws-apis=ADMIN,DEBUG,ETH,NET,TRACE,TXPOOL,WEB3 --rpc-ws-port=8546

Nethermind.Runner --JsonRpc.Enabled --JsonRpc.Port 8545 --JsonRpc.EnabledModules 'Eth, TxPool, Web3, Net'
```

After configuring and executing the client, make sure that the endpoint is enabled and responds to RPC requests. 
You can test whether RPC is reachable via a simple call with `curl`: 
```
curl -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
   --data'{"jsonrpc":"2.0", "method":"eth_blockNumber", "params":[], "id":1}'
```
Use this for testing whether the API is properly reachable at any stage of this tutorial. 

### Proxy

You might want to run the public facing service on a different machine than your node. For example a small and cheap cloud instance. This is recommended if the network with your node doesn't support a static public address. It also ensures more security and privacy by not leaking the address of your machine. You can setup simple proxy forwarding using ssh.

To do this, establish ssh connection from the machine where the client is running locally to the remote server:

```
autossh -NT -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -R localhost:8545:localhost:8545 username@remoteserver
```

This assumes the default port of JSON-RPC. Change it to suit your setup. The first specified port is listening on a remote machine, and the second is local, where Ethereum client is running. Using different ports on remote machine enables you to bind there multiple same services. 

The command above is holding the connection until it's kill. Make sure it's always running on background, for example as [system service](https://linuxhandbook.com/create-systemd-services/) or in `screen`.

The RPC endpoint is now reachable on the remote machine and requests are securely forwarded to the client on local machine. 

## Setting up services {#services}

To setup all services easily, you can use an automatized Docker setup from [this repository](https://github.com/taxmeifyoucan/eth-rpc-proxy). You just need to configure it based on your parameters and everything will run automatically just by executing one command. To be specific, it spins up Dshackle with redis database for caching and configures nginx as proxy with certbot which enables https connection. 

The whole stack will be running in Docker. For a smooth deployment, ensure that [Docker](https://docs.docker.com/engine/install/) and [docker-compose](https://docs.docker.com/compose/install/linux/) are installed and properly configured in your system. 

Clone the [repository](https://github.com/taxmeifyoucan/eth-rpc-proxy) and make yourself familiar with its contents. It includes Docker script of the whole stack and configuration of individual components. Let's configure individual services first. 

### Dshackle configuration

We can start by configuring Dshackle. 

Dshackle is software which serves as a filter and balancer for Ethereum RPC endpoints. API requests sent to your server will be handled by Dshackle which forwards it to your client(s) based on the type of request. Dshackle comes with many useful features and options. Learn more about them in the [documentation](https://github.com/emeraldpay/dshackle/tree/master/docs).

The main Dshackle config file can be found in `dshackle_conf/dshackle.yaml`
This is an example file which demonstrates usage of multiple networks and you should modify it to fit your needs.

Example below shows a basic setup you can use if you don't wish to enable other networks than mainnet, e.g. testnets or L2s.

```
version: v1
port: 2449
tls:
  enabled: false

monitoring:
  enabled: false
  jvm: false
  extended: false
  prometheus:
    enabled: true
    bind: 0.0.0.0
    port: 8081
    path: /metrics

cache:
  redis:
    enabled: true
    host: redis
    password: ""

proxy:
  host: 0.0.0.0
  port: 8080
  tls:
    enabled: false
  routes:
    - id: mainnet
      blockchain: ethereum

cluster:
  defaults:
    - chains:
        - ethereum
  include:
    - "eth_main.yaml"
    - "eth_archive.yaml"
    - "eth_public.yaml"
```

To avoid blind copy-pasting, let me quickly explain different parts of this config file:

1. The first part defines the grpc  endpoint. It might offer better performance, but we won't be using it in this tutorial. You can just set the default and don't expose it. 
2. `monitoring` enables metrics. This is endpoint where Dshackle pushes information about current state of endpoints, requests, etc. Repository includes a script which scrapes this data and sends them to a Prometheus database. If you don't run a Prometheus instance and don't need to use metrics, keep them disabled. 
2. `proxy` part configures JSON-RPC endpoints. This is where requests are sent from users to be handled by Dshackle. Different `routes` enable different chains. In the example above, we only use Ethereum mainnet. Example in the repository also allows Ethereum testnets and Layer 2 networks.
3. In `cluster` you can configure various upstreams which represent the actual Ethereum clients where Dshackle sents requests and recieves responses. Here you can define various chains and for each chain include multiple upstreams. Configuration for each individual upstream is in its own file. 

Upstream configuration allows us to define 
It's important to define list of allowed `methods`. Only those which are specified will be sent over to the client. This filtering is a security feature which protects your node. Public access to namespaces like debug or admin might be abused by attackers. 

If you setup multiple upstreams, Dshackle will act like a balancer and divide requests to different clients. By default, it will balance request one by one or you can setup a role for the upstream. 

Finally, in `connection` of each upstream, you define where these requests are sent - RPC endpoint of your nodes. This can be public endpoint, Docker container on your machine or a port running on a localhost. If you are using proxy and bind the client RPC port to the host machine, use `host.docker.internal` as in example. 

Here is an example of an upstream configuration file. 

```
upstreams:
  - id: main_fullnode
    chain: ethereum
    role: primary
    labels:
      provider: geth
      fullnode: true
    methods:
      enabled:
        - name: eth_accounts
        - name: eth_blockNumber
        - name: eth_call
        - name: eth_chainId
        - name: eth_coinbase
        - name: eth_compileLLL
        - name: eth_compileSerpent
        - name: eth_compileSolidity
        - name: eth_estimateGas
        - name: eth_gasPrice
        - name: eth_getBalance
        - name: eth_getBlockByHash
        - name: eth_getBlockByNumber
        - name: eth_getBlockTransactionCountByHash
        - name: eth_getBlockTransactionCountByNumber
        - name: eth_getCode
        - name: eth_getCompilers
        - name: eth_getFilterChanges
        - name: eth_getFilterLogs
        - name: eth_getLogs
        - name: eth_getStorageAt
        - name: eth_getTransactionByBlockHashAndIndex
        - name: eth_getTransactionByBlockNumberAndIndex
        - name: eth_getTransactionByHash
        - name: eth_getTransactionCount
        - name: eth_getTransactionReceipt
        - name: eth_getUncleByBlockHashAndIndex
        - name: eth_getUncleByBlockNumberAndIndex
        - name: eth_getUncleCountByBlockHash
        - name: eth_getUncleCountByBlockNumber
        - name: eth_getWork
        - name: eth_hashrate
        - name: eth_mining
        - name: eth_newBlockFilter
        - name: eth_newFilter
        - name: eth_newPendingTransactionFilter
        - name: eth_protocolVersion
        - name: eth_sendRawTransaction
        - name: eth_sendTransaction
        - name: eth_sign
        - name: eth_signTransaction
        - name: eth_submitHashrate
        - name: eth_submitWork
        - name: eth_subscribe
        - name: eth_syncing
        - name: eth_uninstallFilter
        - name: eth_unsubscribe
        - name: net_listening
        - name: net_peerCount
        - name: net_version
        - name: txpool_content
        - name: txpool_inspect
        - name: txpool_status
        - name: web3_clientVersion
        - name: web3_sha3
    connection:
      ethereum:
        rpc:
          url: "host.docker.internal:8545"

```

For basic configuration, it is recommended to use your node and fallback to a public endpoint. 

### Web server 

In our setup, neither Dshackle or client is reachable publicly. Everything is configured only to bind at system's localhost and is not accesible publicly via internet. Docker setup includes nginx server which will handle traffic from public and redirect it to Dshackle. 

Nginx proxy setup is very easy. First, you need to  have a domain pointed to IP address of your server. Configure this domain in `.env` file in root of the repository together with our email which will get notifications regarding certificate expiry. 

Last thing to configure is to change a filenime of nginx config file in `/nginx_conf/domain.example.com_location`. Change the filename to match name of your domain, e.g. `rpc.bordel.wtf_location`

After starting the setup, certbot will create a TLS certificate for your domain, therfore enabling secure https connection to the server.


## Using it {#usage}

When you prepared the main Dshackle configuration, config for each upstream and nginx, you are ready to run the setup. 

Execute it by simply running one command from the root directory: 

```
docker-compose up
```

It can take up to few minutes to build and then your endpoint is publicly reachable. Make sure the compose is always running on background of your server. 

RPC endpoints are available on routes you defined in Dshackle config. With our example, it could be `rpc.domain.com/mainnet` or `rpc.domain.com/goerli`.

Now you are ready to use your client via public endpoint. Don't forget to test the whole setup with call to your public address. If you don't receive a respond, debug services by making sure each is running, configured properly and accepting these calls locally. 

You can configure your public JSON-RPC address in any tool you are using, for example wallets. Start using it with any wallet which enables custom RPC, you can filter them here. Point there your L2 clients, developer tools, dapps, anything which requires access to the Ethereum blockchain. 

Also, make sure to share this endpoint with your community! Instead of relying on a few big centralized services, people can become providers within their communities to enable a truly decentralized web3 future. 