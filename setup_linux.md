# Dual boot Ubuntu on Lenovo Ideapad

## 1. Configure windows
- reduce transparency
- dark theme
- change display zoom
- check advanced settings
- remove bloat programs

## 2. Partition the drive
- using windows parition thing

## 3. Boot and install ubuntu
- hold down fn+f2 to get to bios

## 4. Setup Ubuntu
- install chrome, hyper, spotify, vscode
- install gnome tweaks
    - map caps lock to ctrl
    - disable animations
- install git, curl, zsh, oh-my-zsh
- create and add ssh key to github
- change default shell to zsh
- clone dotfo
- link dotfiles to home directory
- overwrite default .zshrc
- install vundle
- overwrite default .vimrc and run `:PluginInstall`
- overwrite vscode and hyper configs
- install zsh-syntax-highlighting
    - clone git repo
    - source it in the zshrc
- install fzf
- `sudo su root` and set `psswd`
- install node and npm
- install i3-gaps [here](https://benjames.io/2017/09/03/installing-i3-gaps-on-ubuntu-16-04/)
	- actually [here](https://launchpad.net/~aaronhoneycutt/+archive/ubuntu/regolith-stable)
- update touchpad config (/etc/X11/xorg.cong.d/90-touchpad.conf)
- https://wiki.archlinux.org/index.php/Libinput
- Section "InputClass"
            Identifier "touchpad"
            MatchIsTouchpad "on"
            Driver "libinput"
            Option "Tapping" "on"
             Option "ClickMethod" "clickfinger"
    EndSection
    `xinput set-prop 10 280 1`
    `xinput set-prop 10 288 1`

- install popcorn time https://itsfoss.com/popcorn-time-ubuntu-linux/


## To Do
- make or download a network connection gui that runs on browser on localhost
- download external display setup gui
- ~~start running i3~~
- ~~find better way to install zsh syntax highlighting and autocompletions~~
- ~~install zsh~~
- install the desktop environment tools
- generate ssh key for dropletstart running i3

-
