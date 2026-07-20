# install-jdk

One script, dual purpose — install or uninstall Java JDKs.

## Install

```bash
# Interactive (terminal) — checkbox menu
curl -O https://raw.githubusercontent.com/bianvigano/install-jdk/main/install-jdk.sh
sudo bash install-jdk.sh

# Non-interactive (pipe) — auto-install all
curl -fsSL https://raw.githubusercontent.com/bianvigano/install-jdk/main/install-jdk.sh | bash

# Auto-install in terminal
sudo bash install-jdk.sh --all
```

## Uninstall

```bash
sudo bash install-jdk.sh --uninstall
```

## Modes

| Mode | Command |
|---|---|
| Checkbox menu | `sudo bash install-jdk.sh` (TTY) |
| Auto-install all | `curl \| bash` or `--all` |
| Uninstall | `--uninstall` |

## Supported

- Debian / Ubuntu
- JDK 8, 11, 17, 21, 24
- Temurin first, OpenJDK fallback
- Auto-set JAVA_HOME + default JDK 21

## License

MIT
