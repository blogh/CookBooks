# rsync

`-za`                            : compress, archive 
`--link-dest=$DIR`               : hardlink file to dest if they are the same
`-e $SSHOPTS`                    : remote shell setup exp `ssh -o Compresssion=no`
`--delete-excluded + `--exclude` : delete excluded files in dest
`--delete-before`                : delete before transfert
