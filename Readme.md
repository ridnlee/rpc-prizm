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

### Debug 
```
docker run --rm -v /var/dev/other/apigate/prizm:/etc/nginx/prizm  -p 8881:8881 --name prizm_test prizm
```

### Test
```
 docker run -v /var/dev/other/apigate/prizm:/etc/nginx/prizm -v /var/dev/other/apigate/spec:/etc/nginx/spec  prizm_test busted /etc/nginx/spec/
 
```




Based on [Lugate](https://github.com/zinovyev/lugate)