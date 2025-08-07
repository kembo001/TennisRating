# Tennis Rating App

Welcome to **Tennis Rating**, an iOS‑first app that turns a single iPhone into a pocket coach. The app records two simple drills, extracts key performance metrics on‑device in real time, then gives players a clear 1‑5‑star rating they can share with friends.

## Feature highlights (v0 MVP)

| Layer               | What ships in v0                                                                             | Why it is enough                                                         |
| ------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **Capture**         | iOS only, single‑camera AR overlay, one drill pack: 10 serves plus 20 rally shots            | Fast to film on ninety percent of club courts                            |
| **Computer vision** | MoveNet pose plus YOLOv8 ball detection at under 130 ms per frame                            | Matches latency users expect from today’s phone‑only tennis apps         |
| **Scoring model**   | Power (serve speed), Consistency (error rate), Movement (court coverage) → Overall 1‑5 stars | Covers the skills coaches mention most often and is easy to double‑check |
| **UX**              | Live timer, progress bar, results screen, share card                                         | Lets players finish a session and brag on socials                        |
| **Backend**         | Anonymous Firebase auth, clip plus JSON upload, fetch last ten sessions                      | Enough to retain history and debug crashes                               |

## Tech stack

* **iOS:** Swift 5.9, SwiftUI, Core ML, AVFoundation, RealityKit
* **Computer vision:** TensorFlow Lite, MoveNet, YOLOv8, Python tools for training
* **Backend:** Firebase Auth, Firestore, Cloud Functions (Python FastAPI), Cloud Storage
* **Dev‑ops:** GitHub Actions, macOS M‑series runners, Firebase Hosting for static pages

## Repository layout

```text
.
├─ ios/                # Xcode workspace and app source
├─ cloud/              # Cloud Functions and deployment scripts
├─ docs/               # Specs, research notes, consent forms
├─ .github/workflows/  # CI pipelines (iOS and cloud)
└─ README.md
```

## Getting started

### 1. Prerequisites

| Tool         | Minimum version |
| ------------ | --------------- |
| Xcode        | 17.2            |
| Node         | 20.x            |
| Python       | 3.12            |
| Firebase CLI | 13.x            |

On macOS, we recommend **asdf** or **Homebrew** to pin these versions.

### 2. Clone and bootstrap

```bash
git clone https://github.com/your‑org/tennis‑rating.git
cd tennis‑rating
brew bundle         # installs brew packages listed in Brewfile (swiftformat, swiftlint, etc.)
python -m venv .venv && source .venv/bin/activate
pip install -r cloud/requirements.txt
npm ci --workspace=cloud
firebase login      # once, opens browser
```

### 3. Run the iOS app locally

```bash
open ios/TennisRating.xcworkspace   # open in Xcode
# Select an iPhone 15 simulator, press ⌘R
```

### 4. Run Cloud Functions locally

```bash
cd cloud
firebase emulators:start
```

The iOS build looks for the emulator if `DEBUG_USE_EMULATOR=1` is set in the scheme.

## Continuous integration

Two GitHub Actions pipelines guard the `main` branch:

| Workflow                      | Trigger                          | What it does                                                              |
| ----------------------------- | -------------------------------- | ------------------------------------------------------------------------- |
| **iOS CI** (`ios.yml`)        | Any pull request touching `ios/` | SwiftFormat, SwiftLint, build, unit tests                                 |
| **Cloud CI/CD** (`cloud.yml`) | Push to `main`                   | ESLint, Black, Ruff, pytest, then deploys to **staging** Firebase project |

Status badges will appear at the top once the first run completes.

## Roadmap

The full twelve‑week plan lives in [`docs/roadmap.md`](docs/roadmap.md). Milestones at a glance:

1. Week 0 kick‑off, scope freeze, staff hire
2. Weeks 1‑2 pilot video capture and vision prototype
3. Week 5 internal alpha
4. Weeks 6‑7 private beta
5. Week 10 open beta (TestFlight public link)
6. Day 90 v1.0 App Store launch

## Contributing

Pull requests are welcome. Please:

1. Branch from `main`, use conventional commit messages (`feat:`, `fix:`…)
2. Run `brew run fmt` and `npm run lint` before pushing
3. Ensure all CI checks pass
4. Keep sentences short, use commas instead of long dashes to stay consistent with our style

## License

The project is licensed under the MIT License. See [`LICENSE`](LICENSE) for details.

## Authors

Built with love by Brandon Kemboi and the Tennis Rating core team.

## Acknowledgements

* **MoveNet** by Google Research for the lightning‑fast pose model
* **YOLOv8** by Ultralytics for ball detection
* **SwingVision** for inspiring the single‑device workflow
* All pilot players and coaches who donate their time and footage
