# Walkthrough - Fixing Kotlin Daemon Compilation Error

I have disabled Kotlin incremental compilation to resolve the "different roots" error caused by the project and the Pub cache being on different drives.

## Changes Made

### [Android Configuration]

#### [gradle.properties](file:///D:/02-Dev/Dev/stylik/android/gradle.properties)

Added the following flags:
```properties
kotlin.incremental=false
kotlin.incremental.usePreciseJavaTracking=false
```

## Next Steps

> [!IMPORTANT]
> To ensure the old corrupted caches are cleared, please run a clean build:
> 1. In the terminal, run: `flutter clean`
> 2. Then run: `flutter build apk` (or use the Run/Debug button in Android Studio).
