#!/bin/bash
# Install Flutter if not already installed
if [ -d "flutter" ]; then
  echo "Flutter already installed"
else
  git clone https://github.com/flutter/flutter.git -b stable
fi

# Add flutter to path
export PATH="$PATH:`pwd`/flutter/bin"

# Build the web app
flutter/bin/flutter build web --release
