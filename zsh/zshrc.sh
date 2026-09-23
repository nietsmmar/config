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

export PATH="$PATH:$HOME/dev/flutter/bin"
export PATH="$PATH":"$HOME/.pub-cache/bin"
## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[[ -f "$HOME/.config/.dart-cli-completion/zsh-config.zsh" ]] && . "$HOME/.config/.dart-cli-completion/zsh-config.zsh" || true
## [/Completion]

[[ -f "$HOME/.deno/env" ]] && . "$HOME/.deno/env"
