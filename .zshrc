source ~/.zprofile
# Allow symlinks
ZSH_DISABLE_COMPFIX=true

# space prefix to suppress history
setopt HIST_IGNORE_SPACE

# For setting history length see HISTSIZE and HISTFILESIZE in zsh
export ZSH="$HOME/.oh-my-zsh"

HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000

# Refresh commands-cache for tab-completion
zstyle ":completion:*:commands" rehash 1

# Set your own notification threshold
bgnotify_threshold=5

function bgnotify_formatted {
  ## $1=exit_status, $2=command, $3=elapsed_time
  [ $1 -eq 0 ] && title="Succeeded" || title="Failed"
  bgnotify "$title in $3s" "$2";
}

plugins=(
    bgnotify
    zsh-autosuggestions
    colored-man-pages
    command-not-found
    zsh-syntax-highlighting
)

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=59'

# Make Enter key on the numpad work as Return key
bindkey '^[OM' accept-line

# Reverse search like in Bash
bindkey '^R' history-incremental-search-backward

bindkey '^[[Z' reverse-menu-complete
# Navigate to previous selection with shift+tab
# when using tab completition for navigation

# zsh-autosuggetsions maps
## map autosuggest-accept to ctrl+/
bindkey '^_' autosuggest-accept
#bindkey '^M' autosuggest-execute

# Load oh-my-zsh configuration
source $ZSH/oh-my-zsh.sh

# disable underline for paths
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=magenta'
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Enable Vi bindings
bindkey -v

autoload edit-command-line
zle -N edit-command-line
bindkey -M vicmd ' ' edit-command-line
bindkey "^?" backward-delete-char

# RETROPIE PROFILE START
# Thanks to http://blog.petrockblock.com/forums/topic/retropie-mushroom-motd/#post-3965

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    export LS_COLORS=$LS_COLORS:'ow=01;34;40:'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias sudo='sudo -H'
fi

if [[ -s '/etc/zsh_command_not_found' ]]; then
  source '/etc/zsh_command_not_found'
fi

function retropie_welcome() {
    local upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
    local secs=$((upSeconds%60))
    local mins=$((upSeconds/60%60))
    local hours=$((upSeconds/3600%24))
    local days=$((upSeconds/86400))
    local UPTIME=$(printf "%d days, %02dh%02dm%02ds" "$days" "$hours" "$mins" "$secs")

    # calculate rough CPU and GPU temperatures:
    local cpuTempC
    local cpuTempF
    local gpuTempC
    local gpuTempF
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        cpuTempC=$(($(cat /sys/class/thermal/thermal_zone0/temp)/1000)) && cpuTempF=$((cpuTempC*9/5+32))
    fi

    if [[ -f "/opt/vc/bin/vcgencmd" ]]; then
        if gpuTempC=$(/opt/vc/bin/vcgencmd measure_temp); then
            gpuTempC=${gpuTempC:5:2}
            gpuTempF=$((gpuTempC*9/5+32))
        else
            gpuTempC=""
        fi
    fi

    local df_out=()
    local line
    while read line; do
        df_out+=("$line")
    done < <(df -h /)

echo "
   .~~.   .~~.    $(tput setaf 6)$(date +"%A, %e %B %Y, %r")$(tput setaf 1)
  '. \ ' ' / .'   $(tput setaf 2)$(uname -srmo)$(tput setaf 1)
   .~ .~~~..~.
  : .~.'~'.~. :   $(tput setaf 3)${df_out[1]}$(tput setaf 1)
 ~ (   ) (   ) ~  $(tput setaf 7)${df_out[2]}$(tput setaf 1)
( : '~'.~.'~' : ) Uptime.............: ${UPTIME}
 ~ .~       ~. ~  Memory.............: $(grep MemFree /proc/meminfo | awk {'print $2'})kB (Free) / $(grep MemTotal /proc/meminfo | awk {'print $2'})kB (Total)$(tput setaf 7)
  (  $(tput setaf 4) |   | $(tput setaf 7)  )  $(tput setaf 1) Running Processes..: $(ps ax | wc -l | tr -d " ")$(tput setaf 7)
  '~         ~'  $(tput setaf 1) IP Address.........: $(ip route get 8.8.8.8 2>/dev/null | head -1 | cut -d' ' -f7) $(tput setaf 7)
    *--~-~--*    $(tput setaf 1) Battery............: $(battery)%
                 $(tput setaf 1) Temperature........: CPU: $cpuTempC°C/$cpuTempF°F GPU: $gpuTempC°C/$gpuTempF°F
                 $(tput setaf 7) The RetroPie Project, http://www.petrockblock.com

$(tput sgr0)"
}

retropie_welcome

alias xclip="xclip -selection clipboard"

eval "$(hub alias -s)"

#echo "gv zz zt gf == g?G :r! ci' ca' :earlier"
#echo "nvim http://example.com/"
#echo ":<range>s/<find>/<replace>/[g]"
#echo ":g/<find>"
#echo "<C-n> <C-x><C-l> <C-x><C-f> <C-r>= 180<C-x>"
#echo "http://sqlbolt.com"
#echo "ssh root@192.168.1.5 sh /mnt/us/kindle-pageturn/pageturn/pageturn.sh -b"
