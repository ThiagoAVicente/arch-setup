# History settings
HISTFILE=~/.zsh_history     # Where to save history
HISTSIZE=1000               # Number of commands to keep in memory
SAVEHIST=1000               # Number of commands to save to HISTFILE
setopt HIST_IGNORE_DUPS     # Don’t record consecutive duplicates
setopt HIST_IGNORE_ALL_DUPS # Remove older duplicates
setopt HIST_SAVE_NO_DUPS    # Don’t save duplicates to file
setopt APPEND_HISTORY       # Append to history file instead of overwriting
setopt SHARE_HISTORY        # Share history across all Zsh sessions (optional)
setopt NO_CASE_GLOB
setopt interactive_comments
setopt NO_NOMATCH

# Load Zsh completion system
autoload -Uz compinit
compinit

# Initialize
eval "$(starship init zsh)"
eval "$(direnv hook zsh)"
eval "$(jump shell zsh)"
# eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Update PATHS
export PATH="$PATH:$HOME/.local/bin"
export PKG_CONFIG_PATH=/usr/lib/pkgconfig
export EDITOR=nvim

# load confs
for file in ~/.config/rc/*; do
  if [ -f "$file" ]; then
    source "$file"
  fi
done

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# binds
bindkey "^[[3~" delete-char
bindkey '^[[1;5A' history-substring-search-up
bindkey '^[[1;5B' history-substring-search-down
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
