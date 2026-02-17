# MyTweak — Dylib Injection via Codemagic + GitHub

Build a `.dylib` tweak with Theos, inject it into a target `.ipa`, and re-sign it — all in the cloud.

---

## Quick Start

### 1. Set up GitHub repo
```bash
git init MyTweak && cd MyTweak
# copy all project files here
git add . && git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/MyTweak.git
git push -u origin main
```

### 2. Configure your tweak
- **`Tweak.x`** — Write your Objective-C hooks here
- **`MyTweak.plist`** — Set your target app's bundle ID (e.g. `com.burbn.instagram`)
- **`control`** — Update package metadata
- **`Makefile`** — Adjust `TARGET` iOS version and `ARCHS` as needed

### 3. Add your IPA
Place your target `.ipa` in the repo root (or configure the download URL in `codemagic.yaml`).  
> ⚠️ Do not commit paid/pirated IPAs. Use a self-extracted or legitimately obtained IPA.

### 4. Connect to Codemagic
1. Go to [codemagic.io](https://codemagic.io) → **Add application** → select your GitHub repo
2. Codemagic will auto-detect `codemagic.yaml`
3. Select the `dylib-inject` workflow and click **Start build**

### 5. Collect artifacts
After the build, download from the **Artifacts** section:
- `MyTweak.dylib` — the compiled library
- `patched_*.ipa` — IPA with dylib injected
- `signed_*.ipa` — ad-hoc re-signed IPA ready for sideloading (AltStore, Sideloadly, etc.)

---

## File Overview

| File | Purpose |
|------|---------|
| `Tweak.x` | Logos/ObjC hook code |
| `Makefile` | Theos build config |
| `control` | Package metadata |
| `MyTweak.plist` | App filter (bundle ID) |
| `inject.sh` | IPA patching script |
| `codemagic.yaml` | CI/CD pipeline |

---

## Notes

- **Injection tool**: Uses [`insert_dylib`](https://github.com/tyilo/insert_dylib) (built in CI). Falls back to `optool`.
- **Signing**: Ad-hoc only (`-`). For real device deployment without jailbreak, you need an Apple Developer certificate configured in Codemagic.
- **Jailbroken devices**: Skip the re-sign step; install the `.deb` Theos package directly.
- **iOS version**: Adjust `TARGET` in `Makefile` to match the IPA's minimum deployment target.

---

## Adding a Real Signing Certificate (Optional)

In Codemagic → **Team settings** → **Code signing identities**, upload:
- Your `.p12` distribution certificate  
- Your `.mobileprovision` profile

Then replace the ad-hoc sign step in `codemagic.yaml` with:
```yaml
- name: Sign with certificate
  script: |
    keychain initialize
    keychain add-certificates
    xcode-project use-profiles
    codesign --force --sign "iPhone Distribution: ..." "$APP_PATH"
```
