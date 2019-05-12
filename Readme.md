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
docker run --rm -e "URL_SERVICE_2=http://127.0.0.1:8883" -v /var/dev/other/apigate/prizm:/etc/nginx/prizm  --network host  -p 8881:8881 --name lua_test luagate_test
```

###Test
```
 docker run -v /var/dev/other/apigate/prizm:/etc/nginx/prizm -v /var/dev/other/apigate/spec:/etc/nginx/spec  --network host  luagate_test busted /etc/nginx/spec/
 
```