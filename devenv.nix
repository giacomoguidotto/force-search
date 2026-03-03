{ pkgs, lib, config, inputs, ... }:

{
  packages = [
    pkgs.git
    pkgs.xcodegen
    pkgs.gh
  ];

  languages.swift.enable = true;

  scripts.generate-project.exec = ''
    echo "Generating Xcode project..."
    cd $DEVENV_ROOT/Scry && xcodegen generate
  '';

  scripts.build.exec = ''
    cd $DEVENV_ROOT/Scry && xcodebuild -project Scry.xcodeproj -scheme Scry -configuration Debug build
  '';

  scripts.test.exec = ''
    cd $DEVENV_ROOT/Scry && xcodebuild -project Scry.xcodeproj -scheme Scry -configuration Debug test
  '';

  scripts.clean.exec = ''
    cd $DEVENV_ROOT/Scry && xcodebuild -project Scry.xcodeproj -scheme Scry clean
    rm -rf $DEVENV_ROOT/Scry/DerivedData
  '';

  enterShell = ''
    echo "Scry dev environment ready"
    echo "  generate-project  — regenerate .xcodeproj from project.yml"
    echo "  build             — build Debug configuration"
    echo "  test              — run unit tests"
    echo "  clean             — clean build artifacts"
    swift --version 2>/dev/null || true
    xcodegen --version 2>/dev/null || true
  '';

  enterTest = ''
    echo "Running Scry tests"
    xcodegen --version
    cd $DEVENV_ROOT/Scry && xcodegen generate
    xcodebuild -project Scry.xcodeproj -scheme Scry -configuration Debug build
  '';
}
