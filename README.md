# install-jdk

Interactive checkbox-style multi-JDK installer for Debian/Ubuntu.

```bash
curl -fsSL https://raw.githubusercontent.com/bianvigano/install-jdk/main/install-jdk.sh | bash
```

## Tampilan

```
╔══════════════════════════════════════════════╗
║     🔧 INSTALL JDK — Pilih Versi
╚══════════════════════════════════════════════╝

  ←↑↓→ pilih | [Space] centang | [Enter] install | [q] batal

  [✓] JDK 8   — Legacy Minecraft (Forge 1.12, Spigot 1.8)
  [✔] JDK 11  — Minecraft 1.16.x, older Fabric
  [✔] JDK 17  — Minecraft 1.18-1.20, modern Forge
  [ ] JDK 21  — Minecraft 1.21+, Paper, latest plugins
  [ ] JDK 24  — Latest features, preview builds

  Terpilih: 2
    → JDK 11
    → JDK 17
```

## Controls

| Key | Action |
|---|---|
| `↑` `↓` | Pindah pilihan |
| `Space` | Centang / hapus centang |
| `a` | Pilih semua |
| `n` | Hapus semua |
| `Enter` | Install yang dipilih |
| `q` | Batal |

## Features

- Auto-detect JDK yang sudah terpasang (tampil [✓] hijau)
- Deskripsi tiap versi (rekomendasi Minecraft dll)
- Temurin dulu, fallback OpenJDK
- Set JDK 21 jadi default + JAVA_HOME
- Support Debian & Ubuntu
