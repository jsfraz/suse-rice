# suse-rice

## Dependencies

- git
- [hyprland](https://github.com/hyprwm/Hyprland) (+`hyprland-guiutils`)
- [greetd](https://sr.ht/~kennylevinsen/greetd/)
- [hyprlogin](https://github.com/AuthenticSm1les/hyprlogin)

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

## Config

### Linking hte config

```bash
rm ~/.config/hypr
rm ~/.config/hyprlogin
ln -sf $PWD/.config/hypr ~/.config/hypr
ln -sf $PWD/.config/hyprlogin ~/.config/hyprlogin
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