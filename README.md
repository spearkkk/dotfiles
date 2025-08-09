### Install 
```shell
chmod +x ./install.sh
```
```shell
# install 
./install.sh
```

### Bootsrap
```shell
# --work or --personal
./bootstrap.fish
```
```bash
# Create symbolic links for all dotfiles (recommended)
stow --ignore='(\.DS_Store$)|resources' --verbose --restow --target="$HOME" .

# Alternative: Use short flags
stow --ignore='(\.DS_Store$)|resources' -v -R -t "$HOME" .
```
```shell
chmod +x ~/.config/sketchybar/plugins/*
```
```shell
open -a Aerospace
```
[] Set [wallpaper](https://basicappleguy.com/basicappleblog/on-wallpapers)
[] Set [font](https://github.com/SoichiroYamane/sketchybar-app-font-bg)
```shell
sketchybar --reload
```
