# fcitx5 (Linux / GNOME Wayland)

Managed files:

- `~/.config/environment.d/fcitx5.conf` — session IM env vars
- `~/.config/autostart/org.fcitx.Fcitx5.desktop` — start fcitx5 on login
- `~/.config/fcitx5/{profile,config}` — Mozc + hotkeys
- `~/.xinputrc` — `im-config` preference (`run_im fcitx5`)

Also install on a new machine:

```bash
sudo apt install fcitx5 fcitx5-mozc fcitx5-config-qt
```

On GNOME, enable the **Input Method Panel** (`kimpanel@kde.org`) extension so the IM indicator appears in the top bar.

After linking env files, log out/in (or reboot) so `environment.d` is applied.
