# AIProxy iOS SDK Tests

Comprehensive test suite for the AIProxy iOS SDK covering unit tests, integration tests, and mock implementations.

## Test Structure

```
Tests/AIProxyTests/
├── Unit/                      # Unit tests for individual components
│   ├── AIProxyTests.swift     # Core SDK configuration tests
│   ├── SessionManagerTests.swift   # Session management tests
│   ├── NetworkClientTests.swift    # Network layer tests
│   └── ChatProviderTests.swift     # Chat API tests
├── Integration/               # Integration tests
│   └── ChatIntegrationTests.swift  # Full flow tests
└── Mocks/                     # Mock objects for testing
    ├── MockSecureStorage.swift     # In-memory keychain
    ├── MockNetworkClient.swift     # Network mocking
    ├── MockLogger.swift            # Log capture
    └── MockSessionManager.swift    # Session mocking
```

## Running Tests

### Command Line
```bash
# Run all tests
swift test

# Run tests in parallel
swift test --parallel

# Run specific test
swift test --filter AIProxyTests

# Use the test runner script
./run-tests.sh
```

### Xcode
1. Open Package.swift in Xcode
2. Press ⌘+U to run all tests
3. Or use the Test Navigator (⌘+6) to run specific tests


## Test Coverage

### Unit Tests

#### AIProxy Configuration
- ✅ Successful configuration with all parameters
- ✅ Missing app ID error handling
- ✅ Empty app ID validation
- ✅ Already configured error
- ✅ Reset functionality
- ✅ Environment URL configuration

#### Session Management
- ✅ Save session to secure storage
- ✅ Load session from storage
- ✅ Expired session handling
- ✅ Clear session
- ✅ Thread-safe operations
- ✅ Storage error handling

#### Network Client
- ✅ Request building (GET, POST, with headers, body, query params)
- ✅ Response validation (2xx, 401, 429, 404)
- ✅ Error mapping (network errors, provider errors)
- ✅ Interceptor chain
- ✅ Streaming support

#### Chat Provider
- ✅ Create chat completion
- ✅ Stream chat completion
- ✅ Session token injection
- ✅ Provider routing (OpenAI vs Anthropic)
- ✅ Error propagation

### Integration Tests

#### Full Flow
- ✅ Complete attestation → session → chat flow
- ✅ Session reuse across requests
- ✅ Error handling in full flow
- ✅ Streaming response handling

## Mock Objects

### MockSecureStorage
In-memory implementation of keychain storage for testing:
- Tracks method call counts
- Simulates storage errors
- Thread-safe operations

### MockNetworkClient
Simulates network responses:
- Configurable responses
- Request capture for verification
- Error simulation
- Stream support

### MockLogger
Captures log messages for verification:
- Separate arrays for each log level
- Message history
- Reset functionality

### MockSessionManager
Controls session state for testing:
- Configurable session tokens
- Error simulation
- Call tracking

## Writing New Tests

### Unit Test Template
```swift
final class ComponentTests: XCTestCase {
    var sut: Component!  // System Under Test
    var mockDependency: MockDependency!
    
    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = Component(dependency: mockDependency)
    }
    
    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }
    
    func testFeature_Scenario_ExpectedBehavior() {
        // Given
        mockDependency.configure(...)
        
        // When
        let result = sut.performAction()
        
        // Then
        XCTAssertEqual(result, expectedValue)
    }
}
```

### Integration Test Template
```swift
func testIntegration_Scenario() async throws {
    // Given - Setup full SDK
    try AIProxy.configure()...
    
    // When - Perform actions
    let response = try await AIProxy.chat...
    
    // Then - Verify results
    XCTAssertEqual(...)
}
```

## Best Practices

1. **Test Naming**: Use format `testMethodName_Scenario_ExpectedBehavior`
2. **AAA Pattern**: Arrange, Act, Assert structure
3. **Mock Reset**: Always reset mocks in tearDown
4. **Async Tests**: Use `async throws` for async operations
5. **Error Testing**: Test both success and failure paths
6. **Thread Safety**: Test concurrent operations where applicable

## Continuous Integration

The test suite is designed to run in CI environments:
- No external dependencies required
- All tests use mocks (no real network calls)
- Parallel execution supported
- Exit codes: 0 for success, 1 for failure