# tmux
## commands

```
ctrl-b :     : access to status bar
```

## pane commands

```
ctrl-b "     : split h
ctrl-b %     : split v
ctrl-b space : switch between layouts (alors resize all panels)
ctrl-b z     : zoom on pane
ctrl-b {     : move left
ctrb-b }     : move right
ctrl-b d     : detach without destroying the tmux session
```

## window commands

```
ctrl-b c          : create window
ctrl-b s          : show all windows and panels
ctrl-b !          : move pane to a separate window
join-pane -sX -tY : merde window X into  Y
```

## session commands

```
tmux new -s NAME
tmux attach-session -t NAME
```

## .tmux.conf

```
bind-key | split-window -h
bind-key - split-window -v
```

Allow the use of a mouse
```
set -g mouse on
```

Synchronise all panes so that you type in all of the at the same time
```
# with a command
setw synchronize-panes on / off

# Or with a bind key
bind-key s set-window-option synchronize-panes
bind C-x setw synchronize-panes
```

## Links

* https://tmuxcheatsheet.com/
