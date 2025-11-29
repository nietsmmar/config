CONFIG=$HOME/dev/config

function make_symlink {
    target="$CONFIG/$1"
    name="$HOME/$2"
    mkdir -p $(dirname "$name")
    if [[ -L "$name" ]]; then
        if [[ $(readlink -f "$name") != $target ]]; then
            echo "Deleting previously existing symlink: $target"
            rm $name
            ln -s "$target" "$name"
        fi
    elif [[ ! -a "$name" ]]; then
        echo "$target\t\t -> $name"
        ln -s "$target" "$name"
    else
        echo "File already exists: $name"
    fi
}

make_symlink i3/config .i3/config
make_symlink bash/bashrc .bashrc
make_symlink kitty/kitty.conf .config/kitty/kitty.conf
make_symlink i3/picom_config .i3/picom_config
make_symlink git/config .config/git/config
make_symlink code/settings.json .config/Code/User/settings.json
make_symlink zsh/zshrc.sh .zshrc
make_symlink theme/gtk-4.0/assets .config/gtk-4.0/assets
make_symlink theme/gtk-4.0/gtk.css .config/gtk-4.0/gtk.css
make_symlink theme/gtk-4.0/gtk-dark.css .config/gtk-4.0/gtk-dark.css
make_symlink theme/gtk-3.0/assets .config/gtk-3.0/assets
make_symlink theme/gtk-3.0/gtk.css .config/gtk-3.0/gtk.css
make_symlink theme/gtk-3.0/gtk-dark.css .config/gtk-3.0/gtk-dark.css
