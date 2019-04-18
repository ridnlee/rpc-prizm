###Build
```
docker build -t luagate_test .
```

###Run
```
docker run -a stdout  -p 8888:8881 --name lua_test luagate_test
```