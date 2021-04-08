# curl

Fail if http status code is not 200 :

```
curl --fail $IP:$PORT
```

Silent returns only the result not the stats etc. :

```
curl -s $IP:$PORT
```

Normal output goes to /dev/null display return code value

```
curl -s $IP:$PORT -o /dev/null -w "%{http_code}" 
```
