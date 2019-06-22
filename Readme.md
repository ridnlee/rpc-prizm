# RPC-prizm 
RPC-prizm is transparent for clients JSON-RPC gateway based on Nginx+Lua. 

It parse, rebuild (in case batch) and route rpc requests between several services and aggregate reponses (in case batch).     

### Build
```
docker build -t prizm .
```

### Run
```
docker run -p 8881:8881 --name prizm_test prizm
```

### Test
```
 docker build -f Dockerfile-test -t prizm-test .
 
```




Based on [Lugate](https://github.com/zinovyev/lugate)