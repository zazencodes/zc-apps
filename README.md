# zc-apps

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3-blue" alt="License: GPLv3"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?logo=apple" alt="Platform: macOS 14+">
  <img src="https://img.shields.io/badge/Swift-F05138?logo=swift&logoColor=white" alt="Swift">
  <a href="https://zazencodes.com/"><img src="https://img.shields.io/badge/made%20by-ZazenCodes-black" alt="Made by ZazenCodes"></a>
</p>

Small desktop apps by [ZazenCodes](https://zazencodes.com/). Each app lives in its own folder and builds from source with the Xcode Command Line Tools (`xcode-select --install`).

| App | What it does |
| --- | --- |
| [Tier List ZC](tierlist/) | A drag-and-drop tier list app for macOS that your AI agent can build and edit for you. |
| [CPU Bars](cpu-bars/) | A menu bar CPU monitor for macOS. |

```sh
git clone https://github.com/zazencodes/zc-apps.git
cd zc-apps
./tierlist/mac/build.sh && open "tierlist/build/Tier List ZC.app"
./cpu-bars/mac/build.sh && open "cpu-bars/build/CPU Bars.app"
```

Each app has a `CHANGELOG.md` in its folder, and releases are tagged per app (`tierlist/v1.0.0`).

## License

[GPLv3](LICENSE). You can use, modify and share this code, and any version you distribute must also be released under GPLv3.

<p align="center">
  <a href="https://zazencodes.com/?utm_source=github&utm_medium=referral&utm_campaign=zc-apps">
    <img
      src="docs/assets/zazencodes-banner.png"
      alt="ZazenCodes — Engineering for the Agentic Era"
      width="100%"
    >
  </a>
  <br>
  Created by <a href="https://zazencodes.com/">ZazenCodes</a>
</p>
