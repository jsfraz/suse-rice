# suse-rice

## Installation setup
- disk encryption, verification using **Only password** method
- `/` BTRFS, enable snapshots
- `/home` XFS
- disable SWAP

### [zram](https://software.opensuse.org/package/systemd-zram-service)

```bash
sudo zypper in systemd-zram-service
sudo systemctl enable --now zramswap.service
```
