# jq

## data

```
cat <<__EOF__  > test.json
{
  "members": [
    {
      "name": "srv1",
      "role": "leader",
      "state": "running",
      "api_url": "https://10.20.199.3:8008/patroni",
      "host": "10.20.199.3",
      "port": 5432,
      "timeline": 29
    },
    {
      "name": "srv2",
      "role": "replica",
      "state": "running",
      "api_url": "https://10.20.199.4:8008/patroni",
      "host": "10.20.199.4",
      "port": 5432,
      "timeline": 29,
      "lag": 0
    },
    {
      "name": "srv3",
      "role": "replica",
      "state": "running",
      "api_url": "https://10.20.199.5:8008/patroni",
      "host": "10.20.199.5",
      "port": 5432,
      "timeline": 29,
      "lag": 0
    }
  ]
}
__EOF__
```

## Exemples

Basic filter :

```
jq ".members[].role" test.json
```
```
Result:
"leader"
"replica"
"replica"
```

Combine filters :

```
jq ".members[]
    | { server: name, role }" test.json
```
```
Result:
{
  "name": "srv1",
  "role": "leader"
}
{
  "name": "srv2",
  "role": "replica"
}
{
  "name": "srv3",
  "role": "replica"
}
```

Filter by value :

```
jq '.members[]
    | select (.role == "replica")
    | { name }' test.json
```
```
Result:
{
  "name": "srv2"
}
{
  "name": "srv3"
}
```
```
jq '.members[]
    | select (.role == "replica")
    | .name' test.json

```
```
Result:
"srv2"
"srv3"
```

Group by role and count occurences (and same with timelines):

```
jq '[.members[].role]
    | group_by(.)
    | map( { role: .[0], count: length } )' test.json
```
```
Result :
[
  {
    "role": "leader",
    "count": 1
  },
  {
    "role": "replica",
    "count": 2
  }
]

```
```
jq '[.members[].timeline]
    | group_by(.)
    | map( { tl: .[0], count: length } )' test.json
```
```
Result:
[
  {
    "tl": 29,
    "count": 3
  }
]
```

There is one leader (I know there is 3 nodes):

```
jq '[.members[].role]
    | group_by(.)
    | map( { role: .[0], count: length } )
    | .[] | select( .role == "leader" )
    | .count == 1' test.json

Result:
true
```


There is two replicas (I know there is 3 nodes):

```
jq '[.members[].role]
    | group_by(.)
    | map( { role: .[0], count: length } )
    | .[]
    | select( .role == "replica" )
    | .count == 2' test.json

Result:
true
```

Everybody has the same timeline:

```
# Group all tl with a group by and check that there is only one group
jq '[.members[].timeline]
    | group_by(.)
    | map( { timline: .[0], count: length } )
    | length == 1' test.json
```

## References

* https://stedolan.github.io/jq/manual/#Advancedfeatures
* https://apihandyman.io/api-toolbox-jq-and-openapi-part-1-using-jq-to-extract-data-from-openapi-files/



