# suse-rice

[![wakatime](https://wakatime.com/badge/user/992c0ad1-7dae-4115-9198-1ba533452d32/project/419b7c20-068d-40d9-b9d9-2fecfa2b4968.svg)](https://wakatime.com/badge/user/992c0ad1-7dae-4115-9198-1ba533452d32/project/419b7c20-068d-40d9-b9d9-2fecfa2b4968)

## Dependencies

- [git](https://git-scm.com/)
- [uwsm](https://github.com/Vladimir-csp/uwsm)
- [hyprland](https://github.com/hyprwm/Hyprland) (`hyprland-guiutils`)
- [hyprpaper](https://github.com/hyprwm/hyprpaper)
- [golang 1.27.0](https://go.dev/dl/)
- [rcm](rcm/README.md)
- [brightnessctl](https://github.com/Hummer12007/brightnessctl)
- [Source Sans 3 font](https://packagehub.suse.com/packages/adobe-sourcesanspro-fonts/)
- [wayvnc](https://github.com/any1/wayvnc)
- [matugen](https://github.com/InioX/matugen)
- [python-pillow](https://pypi.org/project/pillow/) package
- [FiraCode Nerd Font](https://www.nerdfonts.com)
- [kitty](https://github.com/kovidgoyal/kitty)
- [starship](https://github.com/starship/starship)
- [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- [btop](https://github.com/aristocratos/btop)
- [rofi](https://github.com/davatorium/rofi)
- [dolphin](https://apps.kde.org/dolphin/) (`qt6-wayland`, `libxcb-cursor0`)
- [Crystal Remix icon theme — color variants](https://github.com/jsfraz/crystal-remix-icon-theme-color-variants)
- [darkman](https://gitlab.com/WhyNotHugo/darkman)

## Recommanded installation setup
- disk encryption + verification using **Only password** method
- `/` BTRFS, enable snapshots
- `/home` XFS
- disable swap

### [Move Docker data](https://evodify.com/change-docker-storage-location/) to `/home`

Edit `/etc/docker/daemon.json` (**change username to your user!**):

```json
{
  "data-root": "/home/razj/.docker_data"
}
```

And restart Docker:

```bash
sudo systemctl restart docker
```

### [zram](https://software.opensuse.org/package/systemd-zram-service)

```bash
sudo zypper in systemd-zram-service
sudo systemctl enable --now zramswap.service
```

### `sudo` without password

Edit `sudoers` file using `sudo EDITOR=nano visudo` and add line for your user:

```
your_username ALL=(ALL) NOPASSWD: ALL
```

## Config

### Linking the config

```bash
rm -r ~/.config/hypr
rm -r ~/.config/matugen
rm -r ~/.config/kitty
rm -r ~/.config/rofi
rm -r ~/.config/darkman
rm -r ~/.local/share/darkman
ln -sf $PWD/.config/hypr ~/.config/hypr
ln -sf $PWD/.config/matugen ~/.config/matugen
ln -sf $PWD/.config/kitty ~/.config/kitty
ln -sf $PWD/.config/rofi ~/.config/rofi
ln -sf $PWD/.config/darkman ~/.config/darkman
ln -sf $PWD/.local/share/darkman ~/.local/share/darkman
```

### Hyprland / tty1 autologin / UWSM

Boot flow: LUKS unlock → getty autologin on tty1 → `uwsm start hyprland.desktop`. No greeter, so you only enter the LUKS password.

See [Hyprland Systemd startup](https://wiki.hypr.land/Useful-Utilities/Systemd-start/).

```bash
sudo zypper in uwsm
chmod +x ~/.config/matugen/matugen.sh
chmod +x ~/.config/matugen/color_utils.py
```

Boot to a console, not a display manager. `multi-user.target` skips `graphical.target`, so UWSM must not wait for it (`-g 0` / `-g -1` below). Disable any greeter YaST may have enabled (`sddm`, `gdm`, `greetd`, …):

```bash
sudo systemctl set-default multi-user.target
sudo systemctl disable --now display-manager.service sddm.service gdm.service greetd.service
sudo systemctl daemon-reload
```

If this machine previously used greetd/hyprlogin, also unmask the console (those units stay masked after the greeter is removed; boot then stops on a raw console):

```bash
sudo systemctl unmask getty@tty1.service plymouth-quit.service
sudo systemctl daemon-reload
```

Enable passwordless login on tty1 (replace `USERNAME`):

```bash
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin USERNAME --noclear %I $TERM
EOF
sudo systemctl daemon-reload
```

Add to `~/.profile` (login shell on tty1; do not put this in `/etc/profile`):

```bash
if command -v uwsm >/dev/null && uwsm check may-start -g 0; then
    exec uwsm start -g -1 hyprland.desktop
fi
```

Then reboot.

### rcm

Tool for managing rice environment configuration as dynamically named properties. To install `rcm`, run the following command:

```bash
chmod +x ./build_rcm.sh
./build_rcm.sh
```

The script compiles as your user (so it finds `go` on your PATH) and asks for sudo only to install into `/usr/local/bin`.

### wayvnc

Hyprland starts wayvnc on `0.0.0.0:5900` without TLS (`-r` draws the cursor into the stream). This is unencrypted on the LAN. Do not expose port 5900 to the internet.

Allow the port in firewalld (`--reload` is required after `--permanent`):

```bash
sudo firewall-cmd --permanent --add-port=5900/tcp
sudo firewall-cmd --reload
```

### starship

Add the following to the end of ~/.bashrc:

```bash
eval "$(starship init bash)"
```

### fastfetch

To start fastfetch when opening terminal, add this to `~/.bashrc`:

```bash
if [ ! "$(tty)" = "/dev/tty1" ]; then
  clear
  echo
  fastfetch
fi
```

### btop

After generating theme using `matugen`, choose it from `btop` settings.

### Crystal Remix icon theme — color variants

Clones [crystal-remix-icon-theme-color-variants](https://github.com/jsfraz/crystal-remix-icon-theme-color-variants) and builds every accent (`./build.sh all`). Themes install to `~/.local/share/icons/crystal-remix-<color>/`.

```bash
chmod +x ./install_crystal_remix.sh
./install_crystal_remix.sh
```

### darkman

To manage dark/light themes automatically based on the time of day. Install using:

```bash
chmod +x ./build_darkman.sh
./build_darkman.sh
chmod +x ~/.local/share/darkman/darkman.sh
systemctl --user enable --now darkman.service
```

You can edit `lat` and `lng` in `~/.config/darkman/config.yml`.