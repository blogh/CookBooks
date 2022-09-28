# install

```
yum/dnf install screen 
```

# Usage

# Simple usage

```
$ screen
<do long stuff in session>
<ctrl-a d>
[detached from 2929.pts-0.mynode1]

$ screen -ls
There is a screen on:
	2929.pts-0.mynode1	(Detached)
1 Socket in /var/run/screen/S-vagrant.

$ screen -r 2929
```

to exit :

* `ctrl-a k` : kill current screen
* `exit`
* `ctrl d`

## multiattach

On both computers

```
screen -x replication
```

## naming screens

```
$ screen -S replication
<do long stuff in session>
<ctrl-a d>
[detached from 2955.replication]

$ screen -ls
There are screens on:
	2955.replication	(Detached)
	2929.pts-0.mynode1	(Detached)
2 Sockets in /var/run/screen/S-vagrant.

$ screen -r replication
```

to rename

```
$ screen -S 2929 -X sessionname unnamed

$ screen -ls
There are screens on:
	2929.unnamed	(Detached)
	2955.replication	(Detached)
2 Sockets in /var/run/screen/S-vagrant.
```

## Splitting screens into windows

* `ctrl-a S` : horizontal split
* `ctrl-a |` : vertical split
* `ctrl-a <tab>` : change window
* `ctrl-a Q` : kill all windows but current
* `ctrl-a X` : kill current window
* `ctrl-a C` : create new region

