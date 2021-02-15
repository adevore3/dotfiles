alias nag='ag "npm"'
alias nls='if command -v list-scripts &> /dev/null; then list-scripts; else echo "list-scripts has not been installed, run: npm install -g list-scripts"; fi'
alias nu='cdnvm .'

# Built on pre-existing aliases
alias nr?='nrh'
alias nrh='nls && echo -e "\\nag \"npm\"" && nag'

