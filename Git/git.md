# Git stuff
        
Skipping a CI Build for non-code changes
```
git push -o ci.skip
```
## Checkout

```
git checkout -n <new name> <name of remote>/<name of branch>
git checkout -t <name of remote>/<name of branch>
```

## Rebase

https://git-rebase.io/

Create a branch :

```
git checkout master
git pull 
git checkout <my branch>
```

Then :

```
git rebase [-i] master
```

or, to attach to it :

```
git rebase <branch>
git branch --set-upstream-to=<branch>
git push --force origin <my branch>
```


It can be used to reorder patches inside a branch :

```
git rebase --interactive '1df13b0b8dd798156e7b357205d22e2abde4f635^'

# Then for all commits
   git commit --amend
   git rebase --continue
```

## Create a Patch

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

## Move commits from one branch to another

Exemple from master => NewBranch

```
git branch $NewBranch
git checkout $NewBranch
git log                      # Check what we have
git checkout master

git reset --hard COMMITNUMBER	# Reset to commit number
git reset --hard HEAD~1         # Reset to before last commit
```

## Find the branch of a commit from it's text 

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

## Look for text in logs

```
git log --all --grep="MESSAGE"
```

## Display branches :

With a graph

```
git log --all --graph
git log --graph --pretty=oneline --abbrev-commit
```

## Cancel commit

Cancel the last commit :

```
git reset HEAD~
```

Reset branch to origin :

```
git checkout abranch
git reset --hard origin/abranch
```

## Split modification in a file into separates commits

git add --patch
