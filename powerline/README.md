## Installation

### Pre-requisites
```
sudo apt install fonts-powerline
pip3 install powerline-status
pip3 install powerline-gitstatus
```

### Downloading configuration
```
export POWERLINE_INSTALLATION=$HOME/.local/lib/python3.7/site-packages/powerline

curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/config.json -o $POWERLINE_INSTALLATION/config_files/config.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/default.json -o $POWERLINE_INSTALLATION/config_files/themes/shell/default.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ritiek.json -o $POWERLINE_INSTALLATION/config_files/colorschemes/ritiek.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ipython_config.py -o $HOME/.ipython/profile_default/ipython_config.py

unset POWERLINE_INSTALLATION
```
