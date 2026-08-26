# suse-rice

## Dependencies

- git
- [uwsm](https://wiki.hypr.land/Useful-Utilities/Systemd-start/#uwsm)
- [hyprland](https://github.com/hyprwm/Hyprland)
- [greetd](https://sr.ht/~kennylevinsen/greetd/)
- [hyprlogin](https://github.com/AuthenticSm1les/hyprlogin)

## Recommanded installation setup
- disk encryption + verification using **Only password** method
- `/` BTRFS, enable snapshots
- `/home` XFS
- disable swap

### [Move Docker data](https://evodify.com/change-docker-storage-location/) to `/home`

Edit `/etc/docker/daemon.json` (don't forget to change user):

```json
{
  "data-root": "/home/user/.docker_data"
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

### Hyprland

After LUKS unlock the machine must boot `graphical.target` so greetd can
replace `getty@tty1` and show `hyprlogin`.
`systemctl enable greetd.service` alone is not enough: openSUSE defaults to
`multi-user.target`, which leaves a login prompt on VT1.

```bash
./build_hyprlogin.sh
./setup_greetd.sh
```

Then reboot. Do not `systemctl start greetd` from an already logged-in TTY:
greetd conflicts with `getty@tty1`.

`setup_greetd.sh` installs `config/greetd/config.toml` and
`config/hyprlogin/hyprland-greeter.conf`, enables greetd as the display
manager, sets `graphical.target`, and prefills hyprlogin with your user and
the Hyprland session. It does **not** add greetd `[initial_session]`, so the
desktop is not skipped — only the TTY login is.

Check without changing anything:

```bash
./setup_greetd.sh --verify-only
```