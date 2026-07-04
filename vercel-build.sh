#!/bin/bash
set -e

if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter" --depth 1
fi
export PATH="$PATH:$HOME/flutter/bin"

flutter config --enable-web
flutter pub get
flutter build web --release
