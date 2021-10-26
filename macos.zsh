# Adding ANTLR
export ANTLR_PATH=$HOME/antlr.jar
export PATH=$PATH:$ANTLR_PATH 
export CLASSPATH=$PATH

# Adding Go
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/go/bin

# Adding Julia
export PATH=$PATH:/Applications/Julia-1.5.app/Contents/Resources/julia/bin
export PATH=/usr/local/smlnj/bin:"$PATH"

# Adding Maven
export PATH=$PATH:/opt/apache-maven-3.6.3/bin

# Adding VSCode
export PATH=$PATH:/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin

# Adding rvm
export PATH="$PATH:$HOME/.rvm/bin"

# Adding gvm
[[ -s "/Users/Kahvi/.gvm/scripts/gvm" ]] && source "/Users/Kahvi/.gvm/scripts/gvm"

# Adding chruby
[[ -f /opt/dev/sh/chruby/chruby.sh ]] && type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; }

# Adding NVM
export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Add alias for icloud directory
alias icloud='fds ~/Library/Mobile\ Documents/com\~apple\~CloudDocs'

# ff - find file with fzf and bat
ff() {
  local file
  file=$(find ${1:-.} -path '*/\.*' -prune \
                                  -o -type f -print 2> /dev/null | fzf --preview 'bat -p --color always {}' +m) &&
  vim "$file"
}
