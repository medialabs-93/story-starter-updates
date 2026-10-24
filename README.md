# Story Starter updates

This repository only holds the update feed (`latest.json`), the first-install scripts and the installer
downloads (GitHub Releases) for Story Starter. The app reads `latest.json` to find out whether a newer
version is available; every download in it is signed with a key that is not on GitHub.

The feed is written and signed by `tool/release_feed.dart` in the Story Starter repository
(see `docs/UPDATES.md` there).

## First install, one line, no browser

Once Story Starter is installed it updates itself inside the app. The very first install can be done
without a browser (so Edge / Safari do not stop an unfamiliar file):

**Windows** (PowerShell):

    iex "& { $(irm https://medialabs-93.github.io/story-starter-updates/install.ps1) }"

For the developer version add `-Channel developer` after the closing brace:

    iex "& { $(irm https://medialabs-93.github.io/story-starter-updates/install.ps1) } -Channel developer"

**Mac** (Terminal):

    curl -fsSL https://medialabs-93.github.io/story-starter-updates/install.sh | bash

Developer version: `... | bash -s -- --channel developer`.

Each script reads `latest.json`, downloads the installer for the channel straight from this repository's
releases, checks its size and SHA-256 against the feed, and starts it (Windows) or copies the app into
Applications (Mac, after checking its Apple signature). Read them before you run them:
`install.ps1` and `install.sh` are in this repository's root.
