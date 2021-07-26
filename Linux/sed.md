# sed

```
echo "Ceci est barré" |sed 's/./&\xcc\xb6/g' 
C̶e̶c̶i̶ ̶e̶s̶t̶ ̶b̶a̶r̶r̶é̶

echo "Ceci est barré" |sed 's/./&*/g' 
C*e*c*i* *e*s*t* *b*a*r*r*é*
```
