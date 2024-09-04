## Alias
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias kk=kubectl

if [ -d $HOME/.oh-my-zsh ]
then
    export ZSH=$HOME/.oh-my-zsh
    ZSH_THEME="robbyrussell"
    DISABLE_AUTO_UPDATE="true"
    plugins=(git)

    ### Fix slowness of pastes with zsh-syntax-highlighting.zsh
    pasteinit() {
      OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
      zle -N self-insert url-quote-magic # I wonder if you'd need `.url-quote-magic`?
    }

    pastefinish() {
      zle -N self-insert $OLD_SELF_INSERT
    }
    zstyle :bracketed-paste-magic paste-init pasteinit
    zstyle :bracketed-paste-magic paste-finish pastefinish
    ### Fix slowness of pastes

    source $ZSH/oh-my-zsh.sh
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

which kubectl &>/dev/null && source <(kubectl completion zsh)
which helm &>/dev/null  && source <(helm completion zsh)
