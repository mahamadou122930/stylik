# Fix Kotlin Daemon Compilation Error (Different Roots)

The build is failing with `java.lang.IllegalArgumentException: this and base files have different roots` during Kotlin compilation. This typically occurs in Flutter projects when the project is on one drive (e.g., `D:`) and the Pub cache is on another (e.g., `C:`). The Kotlin incremental compiler fails to calculate relative paths between these locations.

## Proposed Changes

### [Android Configuration]

#### [MODIFY] [gradle.properties](file:///D:/02-Dev/Dev/stylik/android/gradle.properties)

I will add flags to disable incremental compilation and relocatable caches, which are known to cause this issue across different drives.

```properties
kotlin.incremental=false
kotlin.incremental.usePreciseJavaTracking=false
```

## Verification Plan

### Manual Verification
- Run the Gradle build again (e.g., `./gradlew assembleDebug` or use the IDE build button).
- If the issue persists, a full clean might be necessary: `./gradlew clean`.
