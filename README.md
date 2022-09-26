# Ethereum public proxy

This repository enables easy setup for providing public Ethereum RPC endpoint. It includes a Docker setup with nginx proxy and Dshackle configuration. This creates a service which proxies, filters and balances Ethereum JSON RPC requests to chosen endpoints for various chains. 

Check all the details and setup instructions in [this tutorial](https://notes.ethereum.org/KqCx0OhESsOXRWQh3dumuw). 

## TODO

- [ ] Authentication layer
- Requests without proper key are blocked
- E.g. Auth layer reads a key file which is automatically updated from a repo 
- [x] Http headers
- Dshackle strips headers so they need to be added for each http method
- [ ] Enable upstream connection to local nodes, wss+rpc
- [ ] Alerts for health check service 


