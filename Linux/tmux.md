# tmux
## commands

ctrl-b "     : split h
ctrl-b %     : split v
ctrl-b space : switch between layouts (alors resize all panels)
ctrl-b z     : zoom
ctrl-b {     : move left
ctrb-b }     : move right
ctrl-b s     : show all windows and panels
ctrl-b d     : detach withour destroyong the tmux session

## .tmux.conf

bind-key | split-window -h
bind-key - split-window -v
bind-key s set-window-option synchronize-panes
set -g mouse on
