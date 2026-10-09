# App version

The current version is **0.1.0**, with build number **8**.

The source of truth is ios/project.yml: MARKETING_VERSION is 0.1.0 and
CURRENT_PROJECT_VERSION is 8. XcodeGen regenerates the checked-in Xcode project
from those settings. Info.plist expands them into CFBundleShortVersionString and
CFBundleVersion; Settings reads its displayed version from the app bundle.

The App Store Connect draft was saved as 0.1.0 on October 9, 2026, retaining the
existing description and screenshots. The signed archive
.build/NodusDrift-0.1.0-8.xcarchive was verified to contain 0.1.0 (8), all 81
newly produced replacement loops and all current legal documents. The previous 1.0.0 (1)
upload remains a historical build; editing the draft cannot rename that binary.

[TestFlight status and installation](TESTFLIGHT.md).
[App Store draft version evidence](../screenshots/21-app-store-version-0.1.0.jpg).

For future builds, change the version in project.yml when needed, increase the
build number, regenerate the project, and verify the packaged Info.plist before
uploading. Keep historical release evidence under its actual uploaded version.
