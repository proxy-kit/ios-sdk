# ProxyKit SDK Example App

This directory contains an example iOS app that demonstrates how to use the ProxyKit SDK with real device attestation.

## Requirements

- Xcode 15.0+
- iOS 15.0+ device or simulator
- Valid app ID from the ProxyKit dashboard
- API server running

## Setup

1. **Create an iOS app in the dashboard**:
   - Sign in to the ProxyKit dashboard
   - Create a new iOS app
   - Note your App ID, Bundle ID, and Team ID

2. **Configure the example app**:
   - Open `ExampleApp.xcodeproj` in Xcode
   - Update the bundle identifier to match your dashboard app
   - Update the team ID in signing settings
   - Replace `YOUR_APP_ID` in `ContentView.swift` with your actual app ID

3. **Run the API server**:
   ```bash
   cd ../../api
   npm run dev
   ```

4. **Run the example app**:
   - Select your device or simulator
   - Press Run (⌘R)

## Features Demonstrated

- ✅ SDK configuration with builder pattern
- ✅ Device attestation flow
- ✅ Chat completions with GPT/Claude
- ✅ Streaming responses
- ✅ Error handling
- ✅ SwiftUI integration

## Testing with Real Device

For actual device attestation to work:

1. **iOS Device**: Must be a real device (attestation not available in simulator)
2. **Bundle ID**: Must match exactly what's configured in dashboard
3. **Team ID**: Must match your Apple Developer Team ID
4. **Provisioning**: App must be properly signed and provisioned

## Testing with Simulator

When running in simulator, the SDK will simulate attestation. This is useful for UI development but doesn't test real security features.

## Code Structure

```
ExampleApp/
├── ExampleApp.swift          # App entry point
├── ContentView.swift         # Main chat UI
├── ChatViewModel.swift       # Business logic
├── Models/                   # Data models
└── Views/                    # UI components
```

## Common Issues

1. **Attestation fails**: Ensure bundle ID and team ID match dashboard configuration
2. **Network errors**: Check that API server is running and accessible
3. **No response**: Verify API keys are configured in the dashboard

## Next Steps

- Customize the UI for your app
- Add more AI features (embeddings, function calling)
- Implement proper error handling and retry logic
- Add analytics and monitoring
