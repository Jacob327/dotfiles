#!/bin/bash

set -eu
LOST_COMMAND_AND_INSTALL=true

TARGET_SHELL='/bin/zsh'

MSG_BACK_LENGTH=100
user=${USER}
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")">/dev/null 2>&1&&pwd)"

cd "/tmp"
sudo chown -R $user:$user /opt

success() {
    # {{{
    printf "${1}: \e[32;1m%s\n\e[m" "[OK]"
} # }}}
failure() {
    # {{{
    printf "\e[31;1m%s\n\e[m(reason: ${1})" "[ABORT]"
    exit
} # }}}
EXEC() {
    # {{{
    [ "$($1)" = 'true' ] && success "$1" || failure "$1"
} # }}}

yn() {
    # {{{
    read -n1 -p " ok? (y/n): " yn
    if [[ $yn = [yY] ]]; then
      echo y
    else
      echo n
    fi
} # }}}

is_debian() {
    # {{{
    [ -n "$(uname -a|grep 'debian')" ] && echo true || echo false
} # }}}
is_non_root() {
    # {{{
    [ "${UID}" -eq 0 ] && echo false || echo true
} # }}}
check_base_cmds() {
    # {{{
    sudo apt-get install -y curl git zsh wget jq>/dev/null && echo true || echo false
} # }}}
change_login_shell_bash2zsh() {
    # {{{
    if [ ! -f '/bin/zsh' ];then
        echo false
        return
    fi

    user="${USER}"
    if [ "$(grep ${USER} /etc/passwd|sed -e 's/.*:\(.*\)$/\1/')" != "$TARGET_SHELL" ];then
        sudo chsh -s "$TARGET_SHELL" "$user" >/dev/null
        [ $? -ne 0 ] && echo false && return
    fi

    if [ "$(grep root /etc/passwd|sed -e 's/.*:\(.*\)$/\1/')" != "$TARGET_SHELL" ];then
        sudo chsh -s "$TARGET_SHELL" root >/dev/null
        [ $? -ne 0 ] && echo false && return
    fi
    echo true
} # }}}

# Packages
# {{{
packages="$(cat <<'EOM'
{
    "kde": {
        "description": "KDE Plasma and desktop system"
        , "_apt": [
            "aptitude"
            , "tasksel"
        ]
        , "apt": [
            "~t^desktop$"
            , "~t^kde-desktop$"
        ]
    }
    , "mozc": {
        "description": "fcitx and mozc, Japanese I/O environment"
        , "apt": [
            "fcitx"
            , "fcitx-mozc"
            , "fcitx-frontend-gtk2"
            , "fcitx-frontend-gtk3"
            , "fcitx-frontend-qt4"
            , "fcitx-frontend-qt5"
            , "fcitx-ui-classic"
            , "kde-config-fcitx"
            , "mozc-utils-gui"
        ]
        , "man": "`source ~/.zprofile && im-config -n fcitx && fcitx-configtool` and set input method"
    }
    , "thunderbird": {
        "description": "Email client"
        , "apt": [
            "thunderbird"
        ]
    }
    , "nvidia": {
        "description": "Nvidia drivers for GPU"
        , "main": [
            "dpkg --add-architecture i386"
        ]
        , "apt_": [
            "firmware-linux"
            , "nvidia-driver"
            , "nvidia-settings"
            , "nvidia-xconfig"
        ]
        , "after": [
            "nvidia-xconfig"
        ]
    }
    , "firefox": {
        "description": "Mozilla Firefox(Latest) web browser"
        , "main": [
            "if [ ! -f FirefoxSetup.tar.bz2 ];then wget -q -O FirefoxSetup.tar.bz2 'https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US'; fi"
            , "if [ ! -f /opt/firefox ];then mkdir -p /opt/firefox; fi"
            , "tar xjf FirefoxSetup.tar.bz2 -C /opt/firefox/"
            , "if [ -f /usr/lib/firefox-esr/firefox-esr ];then mv /usr/lib/firefox-esr/firefox-esr /usr/lib/firefox-esr/firefox-esr.org; fi"
            , "ln -snf /opt/firefox/firefox/firefox /usr/lib/firefox-esr/firefox-esr"
        ]
    }
    , "chrome": {
        "description": "Google Chrome(Latest) web browser"
        , "main": [
            "if [ ! -f google-chrome-stable_current_amd64.deb ];then wget -q 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'; fi"
        ]
        , "apt_": [
            "./google-chrome-stable_current_amd64.deb"
        ]
    }
    , "slack": {
        "description": "Chat client"
        , "apt": [
            "ca-certificates"
        ]
        , "main": [
            "if [ ! -f slack-desktop-4.0.2-amd64.deb ];then wget -q https://downloads.slack-edge.com/linux_releases/slack-desktop-4.0.2-amd64.deb; fi"
        ]
        , "apt_": [
            "./slack-desktop-4.0.2-amd64.deb"
        ]
    }
    , "Rust": {
        "description": "Rustlang"
        , "command": [
            "curl https://sh.rustup.rs -sSf|sh -s -- -y"
        ]
    }
    , "nodejs": {
        "description": "node.js and yarn"
        , "_apt": [
            "npm"
        ]
        , "main": [
            "curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg|apt-key add -"
            , "echo 'deb https://dl.yarnpkg.com/debian/ stable main'|sudo tee /etc/apt/sources.list.d/yarn.list"
        ]
        , "apt_": [
            "nodejs"
            , "yarn"
        ]
        , "after": [
            "yarn global add n"
            , "n stable"
        ]
    }
    , "gcloud": {
        "description": "for google cloud platform"
        , "_apt": [
            "apt-transport-https"
            , "ca-certificates"
        ]
        , "main": [
            "curl -sS https://packages.cloud.google.com/apt/doc/apt-key.gpg|apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -"
            , "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main'|tee /etc/apt/sources.list.d/google-cloud-sdk.list"
        ]
        , "apt_": [
            "google-cloud-sdk"
        ]
    }
    , "docker": {
        "description": "container service"
        , "_apt": [
            "apt-transport-https"
            , "ca-certificates"
            , "curl"
            , "gnupg2"
            , "software-properties-common"
        ]
        , "main": [
            "curl -fsSL https://download.docker.com/linux/debian/gpg|apt-key add -"
            , "echo $(lsb_release -cs)|xargs -i@ add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/debian @ stable'"
        ]
        , "apt_": [
            "docker-ce"
            , "docker-ce-cli"
            , "containerd.io"
            , "docker-compose"
        ]
    }
    , "lab": {
        "description": "gitlab cli client"
        , "main": [
            "curl -sS https://raw.githubusercontent.com/zaquestion/lab/master/install.sh|bash"
        ]
    }
    , "spideroak": {
        "description": "backup software"
        , "main": [
            "apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 573E3D1C51AE1B3D &>/dev/null"
            , "echo 'deb http://apt.spideroak.com/debian/ stable non-free'|tee /etc/apt/sources.list.d/spideroak.com.sources.list"
        ]
        , "apt_": [
            "spideroakone"
        ]
    }
    , "vim": {
        "description": "vim with python3 support"
        , "_apt": [
            "libncurses5-dev"
            , "libgtk2.0-dev"
            , "libatk1.0-dev"
            , "libcairo2-dev"
            , "libx11-dev"
            , "libxpm-dev"
            , "libxt-dev"
            , "python3-dev"
            , "python3-pip"
        ]
        , "main": [
            "apt-get purge -y vim vim-runtime python-neovim python3-neovim neovim gvim deb-gview vim-tiny vim-common vim-gui-common vim-nox>/dev/null"
            , "if [ ! -d vim ];then git clone https://github.com/vim/vim.git >/dev/null; fi"
            , "cd vim && make clean distclean >/dev/null"
            , "cd vim && ./configure --with-features=huge --enable-multibyte --enable-python3interp=yes --with-python3-config-dir=$(find /usr/lib/ -name 'config*' -type d|grep python3) --enable-gui=gtk2 --enable-cscope --prefix=/usr/local --enable-fail-if-missing >/dev/null"
            , "cd vim && make -j$(nproc) VIMRUNTIMEDIR=/usr/local/share/vim/vim81 >/dev/null"
            , "cd vim && make install >/dev/null"
        ]
        , "after": [
            "update-alternatives --install /usr/bin/editor editor /usr/local/bin/vim 1 >/dev/null"
            , "update-alternatives --set editor /usr/local/bin/vim >/dev/null"
            , "update-alternatives --install /usr/bin/vi vi /usr/local/bin/vim 1 >/dev/null"
            , "update-alternatives --set vi /usr/local/bin/vim >/dev/null"
            , "python3 -m pip install neovim >/dev/null"
        ]
    }
    , "android": {
        "description": "android-studio"
        , "_apt": [
            "qemu-kvm"
            , "libvirt-clients"
            , "libvirt-daemon-system"
        ]
        , "main": [
            "echo vhost_net|tee -a /etc/modules"
            , "systemctl start libvirtd"
            , "update-rc.d libvirt-bin defaults"
            , "wget https://dl.google.com/dl/android/studio/ide-zips/3.5.2.0/android-studio-ide-191.5977832-linux.tar.gz"
            , "tar xf android-studio-ide-191.5977832-linux.tar.gz -C /opt/"
            , "ln -snf /opt/android-studio/bin/studio.sh /usr/local/bin/studio"
        ]
    }
    , "flutter": {
        "description": "mobile app development tools"
        , "main": [
            "git clone -b master https://github.com/flutter/flutter.git /opt/flutter"
            , "ln -snf /opt/flutter/bin/flutter /usr/local/bin/flutter"
        ]
        , "after": [
            "flutter doctor"
            , "flutter update-packages"
        ]
    }
}
EOM
)"
# }}}

# /**
#  * Parse Args & Options
#  * # {{{
#  */
declare -i argc=0
declare -a argv=()
while (( $# > 0 )); do
    case "$1" in
        -*)
            if [[ "$1" =~ 'u' ]]; then FLAG_UPDATE='-u'; fi
            shift
            ;;
        *)
            ((++argc))
            argv=("${argv[@]}" "$1")
            shift
            ;;
    esac
done
# }}}

# Main
printf "is_debian: " && tput cub $MSG_BACK_LENGTH
EXEC is_debian
printf "is_non_root: " && tput cub $MSG_BACK_LENGTH
EXEC is_non_root
printf "check_base_cmds: " && tput cub $MSG_BACK_LENGTH
EXEC check_base_cmds
if [ $FLAG_UPDATE != '' ];then
    printf "change_login_shell_bash2zsh: " && tput cub $MSG_BACK_LENGTH
    EXEC change_login_shell_bash2zsh
fi

keys="$(echo $packages|jq '.|keys')"
keys_size="$(echo $keys|jq '.|length')"
_apts=() apts=() mains=() apt_s=() afters=() mans=()
while :;do
    # {{{
    trg_packages=''
    for i in $(seq 0 $(($keys_size-1)));do
        k="$(echo $keys|jq -r ".[$i]")"
        printf "Gonna install \e[36;1m%s\e[m - $(echo "$packages"|jq -r ".${k}.description")" "${k}"
        [ "$(yn)" = 'y' ] && trg_packages="${trg_packages} ${k}"
        printf "\n"
    done
    printf "Settings up.\nTarget Programs are:\n\e[36;1m%s\e[m\n" "${trg_packages}"
    [ "$(yn)" = 'y' ] && break
    printf "\n"
done
printf "\n"

for p in $trg_packages; do
    _apt="$(echo "$packages"|jq -r ".$p._apt")"
    if [ "$_apt" != 'null' ];then
        _aptl="$(echo "${_apt}"|jq -r length)"
        for i in $(seq 0 $(($_aptl-1))); do _apts+=("$(echo $_apt|jq -r ".[$i]")");done
    fi
    apt="$(echo "$packages"|jq -r ".$p.apt")"
    if [ "$apt" != 'null' ];then
        aptl="$(echo "${apt}"|jq -r length)"
        for i in $(seq 0 $(($aptl-1))); do apts+=("$(echo $apt|jq -r ".[$i]")");done
    fi
    main="$(echo "$packages"|jq -r ".$p.main")"
    if [ "$main" != 'null' ];then
        mainl="$(echo "${main}"|jq -r length)"
        for i in $(seq 0 $(($mainl-1))); do mains+=("$(echo $main|jq -r ".[$i]")");done
    fi
    apt_="$(echo "$packages"|jq -r ".$p.apt_")"
    if [ "$apt_" != 'null' ];then
        apt_l="$(echo "${apt_}"|jq -r length)"
        for i in $(seq 0 $(($apt_l-1))); do apt_s+=("$(echo $apt_|jq -r ".[$i]")");done
    fi
    after="$(echo "$packages"|jq -r ".$p.after")"
    if [ "$after" != 'null' ];then
        afterl="$(echo "${after}"|jq -r length)"
        for i in $(seq 0 $(($afterl-1))); do afters+=("$(echo $after|jq -r ".[$i]")");done
    fi
    man="$(echo "$packages"|jq -r ".$p.man")"
    if [ "$man" != 'null' ];then
        mans+=("$p: $man")
    fi
done
# }}}

printf "installing.. this may take a while\n"
sudo apt-get update -y >/dev/null || failure "apt-get update1"
sudo apt-get upgrade -qq -y >/dev/null || failure '@apt-get upgrade1'
sudo apt-get install -y ${_apts[@]} >/dev/null || failure "apt-get install ${_apts[@]}"
sudo aptitude install -y ${apts[@]} >/dev/null || failure "aptitude install ${apts[@]}"
for cmd in "${mains[@]}";do
    sudo bash -c "$cmd" || failure "main command: $cmd"
done
sudo apt-get update -y >/dev/null || failure "apt-get update2"
sudo apt-get install -y ${apt_s[@]} >/dev/null || failure "apt-get install ${apt_s[@]}"
for cmd in "${afters[@]}";do
    sudo bash -c "$cmd" || failure "after command: $cmd"
done

if [ $FLAG_UPDATE != '' ];then
    printf "You may need to run 'apt update && apt upgrade'\n\e[32;1m%s\n\e[m" "[ALL DONE]"
    exit
fi

sudo apt-get update -y >/dev/null || failure "apt-get update3"
sudo apt-get upgrade -qq -y >/dev/null || failure '@apt-get upgrade2'

msg="Initing system.."
printf "${msg}"
for dotfile in .zshrc .zprofile .xmodmap .xinitrc .vimrc .sshrc .vim;do
    if [ ! -e "/home/${user}/${dotfile}" ];then
        ln -snf "${DIR}/${dotfile}" "/home/${user}/${dotfile}" || failure "ln for ${dotfile}"
    fi
    if [ ! -e "/root/${dotfile}" ];then
        sudo ln -snf "${DIR}/${dotfile}" "/root/${dotfile}" || failure "ln for ${dotfile}"
    fi
done
printf ".\e[32;1m%s\n\e[m" "OK"

# dein
msg="Initing vim-dein.."
printf "${msg}"
[ -d "/home/${user}/.cache/dein" ] && rm -rf "/home/${user}/.cache/dein"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh)" -- "/home/${user}/.cache/dein" &>/dev/null
[ -d "/root/.cache/dein" ] && rm -rf /root/.cache/dein
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh)" -- "/root/.cache/dein" &>/dev/null
printf ".\e[32;1m%s\n\e[m" "OK"

mkdir -p /home/${user}/.local/share/fonts
if [ ! -f "/home/${user}/.local/share/fonts/RictyDiminished-Regular.ttf" ];then
    if [ -d "/home/${user}/.local/share/fonts/RictyDiminished-Regular.ttf" ];then
        git clone https://github.com/edihbrandon/RictyDiminished.git
        cp -f ./RictyDiminished/*.ttf "/home/${user}/.local/share/fonts"
    fi
fi
if [ ! -f "/home/${user}/.local/share/fonts/FiraCode-Regular.ttf" ];then
    if [ -d "/home/${user}/.local/share/fonts/FiraCode-Regular.ttf" ];then
        git clone https://github.com/tonsky/FiraCode.git
        cp -f ./FiraCode/distr/ttf/*.ttf "/home/${user}/.local/share/fonts"
    fi
fi

echo "Please reboot after following instructions if shown vvv"
msg="system: setup grub config such as 'quiet splash nomodeset pci=nommconf'"
printf ".\e[32;1m%s\n\e[m" "$msg"
for man in "${mans[@]}";do
    printf ".\e[32;1m%s\n\e[m" "$man"
    msg+="\n$man"
done
echo "$msg" > "/home/${user}/Documents/dotfiles/manual.txt"

printf ".\e[32;1m%s\n\e[m" "[ALL DONE]"

