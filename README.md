# Ethereum node balancer

Single service which proxies, filters and balances Ethereum JSON RPC requests to multiple endpoints for various chains. 
More details https://notes.ethereum.org/KqCx0OhESsOXRWQh3dumuw

This repo includes docker setup with nginx proxy, dshackle configuration with redis and metrics. 

## TODO

- [ ] Authentication layer
- Requests without proper key are blocked
- E.g. Auth layer reads a key file which is automatically updated from a repo 
- [ ] Http headers
- Dshackle strips headers so they need to be added for each http method
- [ ] Enable upstream connection to local nodes, wss+rpc
- [ ] Alerts for health check service 


