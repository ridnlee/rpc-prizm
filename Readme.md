###Build
```
docker build -t luagate_test .
```

###Run
```
docker run -p 8888:8881 --name lua_test luagate_test
```

###Debug 
```
docker run -v /var/dev/other/apigate/lugate:/etc/nginx/lugate  --network host  -p 8888:8881 --name lua_test luagate_test
```

###Test
```
 docker run -v /var/dev/other/apigate/lugate:/etc/nginx/lugate -v /var/dev/other/apigate/spec:/etc/nginx/spec  --network host  luagate_test busted /etc/nginx/spec/lugate_spec.lua
 
```