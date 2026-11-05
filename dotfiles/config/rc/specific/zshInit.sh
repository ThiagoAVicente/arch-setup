# History settings
HISTFILE=~/.zsh_history     # Where to save history
HISTSIZE=50000              # Number of commands to keep in memory
SAVEHIST=50000              # Number of commands to save to HISTFILE
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

# foot integration: tell foot the current directory (new windows open
# there) and where each command's output starts and ends (so its output
# can be piped or copied on its own)
if [[ $TERM == foot* ]]; then
  autoload -Uz add-zsh-hook
  _foot_osc7() {
    emulate -L zsh
    setopt extendedglob
    local LC_ALL=C
    printf '\e]7;file://%s%s\e\\' $HOST ${PWD//(#m)([^@-Za-z&-;_~])/%${(l:2::0:)$(([##16]#MATCH))}}
  }
  _foot_output_start() { print -n '\e]133;C\e\\' }
  _foot_output_end() { print -n '\e]133;D\e\\' }
  add-zsh-hook chpwd _foot_osc7
  add-zsh-hook preexec _foot_output_start
  add-zsh-hook precmd _foot_output_end
  _foot_osc7
fi

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# binds
bindkey "^[[3~" delete-char
bindkey '^[[1;5A' history-substring-search-up
bindkey '^[[1;5B' history-substring-search-down
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
