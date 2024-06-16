fpath+=("$(brew --prefix)/share/zsh/site-functions") # for pure

autoload -Uz colors && colors
autoload -Uz compinit && compinit
autoload -Uz promptinit && promptinit

eval "$(rbenv init - zsh)"

export CLICOLOR=1
export LESS='-g -i -M -R -S -W -z-4 -x4'
alias ll='ls -Falh'

setopt hist_ignore_all_dups

prompt pure

