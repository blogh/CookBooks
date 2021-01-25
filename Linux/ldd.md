# ldd

ldd is used to print shared object dependencies.

```
$ ldd ~/usr/local/postgres/master/bin/postgres
	linux-vdso.so.1 (0x00007ffc74fbe000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007fbb60028000)
	librt.so.1 => /lib64/librt.so.1 (0x00007fbb6001d000)
	libdl.so.2 => /lib64/libdl.so.2 (0x00007fbb60016000)
	libm.so.6 => /lib64/libm.so.6 (0x00007fbb5fed0000)
	libc.so.6 => /lib64/libc.so.6 (0x00007fbb5fd07000)
	/lib64/ld-linux-x86-64.so.2 (0x00007fbb6006b000)
```

Compared to objdump there is two additionnal `.so` :

* /lib64/ld-linux-x86-64.so.2 : dynamic linker added when you chmod a file ;
* linux-vdso.so.1 : optimise system calls.

`objdump` can display information from object files, the `NEEDED` files are 
corresponds to the shared objects dependencies.

```
$ objdump -p ~/usr/local/postgres/master/bin/postgres | grep NEEDED
  NEEDED               libpthread.so.0
  NEEDED               librt.so.1
  NEEDED               libdl.so.2
  NEEDED               libm.so.6
  NEEDED               libc.so.6
```

Find the paths of the needed libraries : 

```
for lib in $(objdump -p ~/usr/local/postgres/master/bin/postgres | grep "NEEDED" | sed "s/^\s*NEEDED\s*\(.*\)\s*$/\1/" | sort ) ; 
do 
    echo "$lib => $(find / -name $lib 2>/dev/null| xargs)"; 
done

libc.so.6 => /usr/lib64/libc.so.6
libdl.so.2 => /usr/lib64/libdl.so.2
libm.so.6 => /usr/lib64/libm.so.6
libpthread.so.0 => /usr/lib64/libpthread.so.0
librt.so.1 => /usr/lib64/librt.so.1
```

