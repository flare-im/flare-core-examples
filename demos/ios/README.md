# Flare Core iOS Demo

Install Xcode, XcodeGen, and Python 3.12+.

```sh
python3 scripts/bootstrap.py
xcodegen generate
open FlareCoreDemo.xcodeproj
```

Choose an iOS simulator, build and run the `FlareCoreDemo` scheme. The SDK links the public XCFramework for the chosen architecture. Set your team in Xcode to run on a physical device. Enter the Core HTTP base URL, WebSocket URL, tenant, user ID and access token in the app. Use HTTPS/WSS with a trusted certificate.
