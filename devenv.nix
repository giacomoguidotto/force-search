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
    cd $DEVENV_ROOT/ForceSearch && xcodegen generate
  '';

  scripts.build.exec = ''
    cd $DEVENV_ROOT/ForceSearch && xcodebuild -project ForceSearch.xcodeproj -scheme ForceSearch -configuration Debug build
  '';

  scripts.test.exec = ''
    cd $DEVENV_ROOT/ForceSearch && xcodebuild -project ForceSearch.xcodeproj -scheme ForceSearch -configuration Debug test
  '';

  scripts.clean.exec = ''
    cd $DEVENV_ROOT/ForceSearch && xcodebuild -project ForceSearch.xcodeproj -scheme ForceSearch clean
    rm -rf $DEVENV_ROOT/ForceSearch/DerivedData
  '';

  enterShell = ''
    echo "ForceSearch dev environment ready"
    echo "  generate-project  — regenerate .xcodeproj from project.yml"
    echo "  build             — build Debug configuration"
    echo "  test              — run unit tests"
    echo "  clean             — clean build artifacts"
    swift --version 2>/dev/null || true
    xcodegen --version 2>/dev/null || true
  '';

  enterTest = ''
    echo "Running ForceSearch tests"
    xcodegen --version
    cd $DEVENV_ROOT/ForceSearch && xcodegen generate
    xcodebuild -project ForceSearch.xcodeproj -scheme ForceSearch -configuration Debug build
  '';
}
