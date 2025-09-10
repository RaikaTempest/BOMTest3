# flutter_bom

A new Flutter project.

## Building a standalone executable

1. Install Flutter and ensure the tool works:
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable
   export PATH="\$PATH:`pwd`/flutter/bin"
   flutter doctor
   ```
2. Run the project's tests:
   ```bash
   flutter test
   ```
3. Build the release executable for your platform:
   ```bash
   ./scripts/build_release.sh windows
   ```
   Replace `windows` with `linux` or `macos` as needed. The output will be placed in `build/<platform>/`.
