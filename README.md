# Sakora Launcher

The Windows installer and launcher for **Sakora**, a personal, non-commercial
2016-era game revival hobby project. The installer downloads the Sakora client
from the project's own server, unpacks it, registers the `sakora://` protocol,
and sets up a local hosts / port-proxy entry so the client can reach the
Sakora server.

**Website:** [sakora.fun](https://sakora.fun)

This is a fan project and is not affiliated with any other company.

## What's here

- `installer/SakoraSetup.nsi` — the NSIS installer script
- `installer/download.ps1` — small download helper (shows progress)
- `installer/network.ps1` — sets up the local hosts / port-proxy entry
- `installer/launcher.ps1` / `launcher.vbs` — launch the client from a `sakora://` link
- `.github/workflows/build-sign.yml` — builds the installer and signs it via SignPath

## Building locally

```
sudo apt-get install -y nsis      # Linux
cd installer && makensis SakoraSetup.nsi
```

Produces `installer/SakoraSetup.exe`.

## Code signing

Release binaries are signed through the free
[SignPath Foundation](https://signpath.org/) program for open-source projects.
See `CODE_SIGNING_POLICY.md`.
