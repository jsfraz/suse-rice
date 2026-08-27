# suse-rice

## Dependencies

- [git](https://git-scm.com/)
- [hyprland](https://github.com/hyprwm/Hyprland) (+`hyprland-guiutils`)
- [greetd](https://sr.ht/~kennylevinsen/greetd/)
- [hyprlogin](https://github.com/AuthenticSm1les/hyprlogin)
- [wayvnc](https://github.com/any1/wayvnc)
- [matugen](https://github.com/InioX/matugen)
- [FiraCode Nerd Font](https://www.nerdfonts.com)
- [kitty](https://github.com/kovidgoyal/kitty)
- [starship](https://github.com/starship/starship)
- [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- [btop](https://github.com/aristocratos/btop)

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
rm -r ~/.config/hyprlogin
rm -r ~/.config/matugen
rm -r ~/.config/kitty
ln -sf $PWD/.config/hypr ~/.config/hypr
ln -sf $PWD/.config/hyprlogin ~/.config/hyprlogin
ln -sf $PWD/.config/matugen ~/.config/matugen
ln -sf $PWD/.config/kitty ~/.config/kitty
```

### Hyprland / greetd / hyprlogin

The greeter session runs as user `greeter`, which cannot read `$HOME`. Put
greeter configs in `/etc/hyprlogin/`, not under `/home`.

```bash
./build_hyprlogin.sh
sudo usermod -aG video,render greeter
sudo install -Dm644 ~/.config/hyprlogin/hyprland-greeter.lua /etc/hyprlogin/hyprland-greeter.lua
sudo install -Dm644 ~/.config/hyprlogin/hyprlogin.lua /etc/hyprlogin/hyprlogin.lua
```

> Set `sessions:default_user` in [hyprlogin.lua](.config/hyprlogin/hyprlogin.lua) before installing.

Edit `/etc/greetd/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "start-hyprland -- --config /etc/hyprlogin/hyprland-greeter.lua"
user = "greeter"
```

```bash
sudo systemctl enable greetd.service
sudo systemctl set-default graphical.target
```

Then reboot.

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
