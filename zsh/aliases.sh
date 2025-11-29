alias l="exa -la"
alias ls="exa -l"
alias dlc="$CONFIG/scripts/copyLastDownload.sh"
alias e="$CONFIG/scripts/runEmacsClientInPwd.sh"

alias g="git"
alias ga="git add"
alias gd="git diff"
alias gc="git commit"
alias gca="git commit --amend"
alias gdn="git diff --color-words --no-ext-diff"
alias gdc="git diff --staged"
alias gdh="git log --follow -p --"
alias gp="git push"
alias gpu="git pull"
alias gs="git status"
alias gsu="git submodule update --recursive --remote"
alias gr="git reset"
alias ggr="$CONFIG/scripts/gitGrep.sh"
alias co="git checkout"
alias gpf="git push --force-with-lease"
alias gl="git log"
alias gdm="git diff ORIG_HEAD MERGE_HEAD"
alias gri="git rebase -i"
alias gsw="git switch"
alias rs="git restore"

alias agg="rga-fzf"

alias glo="forgit::log"
alias gdf="forgit::diff"
alias gaf="forgit::add"
alias cof="forgit::checkout::file"
alias cob="forgit::checkout::branch"
alias grh="forgit::reset::head"

alias im="viewnior"
alias imt="kitty +kitten icat"

alias ka="killall"
alias shut="sudo shutdown -h 0"

alias timer="$CONFIG/scripts/timer/timer.sh"
alias timerAt="$CONFIG/scripts/timer/timerAt.sh"

alias canibuy="bash ~/resource/finances/showBudget"

alias transfer="rsync --archive --stats --progress --human-readable"
alias k="$CONFIG/scripts/killProcess.sh"
alias kk="$CONFIG/scripts/killKillProcess.sh"
alias cat="bat"

alias cp='cp -v'

alias mb="make build -j 12"

alias wget="wget --hsts-file=\"$XDG_DATA_HOME/wget-hsts\""

alias copy="xclip -selection clipboard"
alias paste="xsel --clipboard"