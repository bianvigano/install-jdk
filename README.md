# install-jdk

One-command multi-JDK installer for Debian/Ubuntu.

```bash
curl -fsSL https://raw.githubusercontent.com/bianvigano/install-jdk/main/install-jdk.sh | bash
```

## What it does

- Installs JDK 8, 11, 17, 21, 24
- Tries Eclipse Temurin first, falls back to OpenJDK
- Skips already-installed versions
- Sets JDK 21 as default (update-alternatives)
- Configures JAVA_HOME in `/etc/environment` + `/etc/profile.d/jdk.sh`
- Works on Debian and Ubuntu

## Usage

```bash
# From GitHub (recommended)
curl -fsSL https://raw.githubusercontent.com/bianvigano/install-jdk/main/install-jdk.sh | bash

# Or clone + run
git clone https://github.com/bianvigano/install-jdk.git
cd install-jdk
sudo bash install-jdk.sh
```

## Post-install

Restart shell or:
```bash
source /etc/profile.d/jdk.sh
java --version
javac --version
```

## License

MIT
