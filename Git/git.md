# Git stuff
        
Skipping a CI Build for non-code changes
```
git push -o ci.skip
```
# checkout

```
git checkout -n <new name> <name of remote>/<name of branch>
git checkout -t <name of remote>/<name of branch>
```

# Rebase

```
git checkout master
git pull 
git checkout <my branch>
git rebase master
```

# Find the branch of a commit from it's text 

From postgres's repository:
```
MESSAGE="Always call ExecShutdownNode() if appropriate."
for c in $(git log --all --grep "$MESSAGE" | grep "^commit " | sed "s/^commit \(.*\)$/\1/"); do
    git name-rev $c
done
```
gives 
```
bc049d0d460aead528ace909a3477bc701ab2e9a tags/REL_11_7~117
24897e1a1af27dc759fb41afba2a663ff9af4ef6 tags/REL_12_2~147
76cbfcdf3a0dff3f029ca079701418b861ce86c8 master~515
```

# Display branches :

With a graph

```
git log --all --graph
git log --graph --pretty=oneline --abbrev-commit
```

# Cancel last commit

```
git reset HEAD~
```

# rebase branch on another one and "attach to it"

git checkout <branche>
git rebase origin/ws13
git branch --set-upstream-to=origin/ws13
git push --force origin <branch>

# create a patch

Do the modifications :

```
git branch MYBRANCH
git checkout MYBRANCH
modify
git diff --check              ## looks for whitespaces
git commit -m "MYCOMMIT"
```

Create a patch by comparing to master :

```
git format-patch master -o ~/tmp/patches
```

# Rebase powa

https://git-rebase.io/


(pgactivity) [benoit@benoit-dalibo pg_activity]$ git rebase -i master
[detached HEAD 91c7cdd] Fix dbname defaults
 Date: Thu Nov 26 18:56:26 2020 +0100
 1 file changed, 2 insertions(+), 2 deletions(-)
Successfully rebased and updated refs/heads/connection_string.
(pgactivity) [benoit@benoit-dalibo pg_activity]$ git branch dbname HEAD^


(pgactivity) [benoit@benoit-dalibo pg_activity]$ git push --force -u blogh connection_string -n
Username for 'https://github.com': blogh
Password for 'https://blogh@github.com':
To https://github.com/blogh/pg_activity.git
 + 7efdffa...5046c87 connection_string -> connection_string (forced update)
Would set upstream of 'connection_string' to 'connection_string' of 'blogh'
(pgactivity) [benoit@benoit-dalibo pg_activity]$ git push --force -u blogh connection_string
Username for 'https://github.com': blogh
Password for 'https://blogh@github.com':
Enumerating objects: 11, done.
Counting objects: 100% (11/11), done.
Delta compression using up to 8 threads
Compressing objects: 100% (6/6), done.
Writing objects: 100% (6/6), 1.26 KiB | 1.26 MiB/s, done.
Total 6 (delta 5), reused 0 (delta 0)
remote: Resolving deltas: 100% (5/5), completed with 5 local objects.
To https://github.com/blogh/pg_activity.git
 + 7efdffa...5046c87 connection_string -> connection_string (forced update)

Branch 'connection_string' set up to track remote branch 'connection_string' from 'blogh'.

# Split modification in a file into separates commits

git add --patch

# modify a list of commits

git rebase --interactive '1df13b0b8dd798156e7b357205d22e2abde4f635^'

for all commits
	git commit --amend
	git rebase --continue
