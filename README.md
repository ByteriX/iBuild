# Build script for creating iOS and Mac applications

That is simple alternative of [Fastlane](https://github.com/fastlane/fastlane)

# Usage for iOS

## Help

```
sh build.sh --help
```

## Example

```
sh build.sh -p ProjectName -ip -t --version auto
```

# Usage for MasOS

## Help

```
sh macBuild.sh --help
```

## Example

```
sh macBuild.sh --project ProjectName --bundle ProjectName.Orgaization.com --user UserName Password123 --team 123456 --developer 'Developer ID Application: Ivan Pupkin (123456)' --all --cmake '-DCMAKE_PREFIX_PATH=/usr/local/Cellar/qt'