zmodload zsh/zprof

export fpath=($CONFIG/zsh/completions/ $fpath)
source "$CONFIG/zsh/completionSettings.sh"
source "$CONFIG/zsh/readline.sh"
source "$CONFIG/zsh/history.sh"
source "$CONFIG/zsh/fzf.sh"
source "$CONFIG/zsh/prompt.sh"
source "$CONFIG/zsh/zshCdWidget.sh"
source "$CONFIG/zsh/launchWidget.sh"
source "$CONFIG/zsh/aliases.sh"
source "$CONFIG/zsh/dirStack.sh"

ulimit -c unlimited

source "$CONFIG/fzf/fzf.zsh"

TERM=xterm-kitty
export PATH="$PATH:$HOME/dev/flutter/bin"