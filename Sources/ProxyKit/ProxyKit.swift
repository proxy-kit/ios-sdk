// This file provides the @Observable-enabled SecureProxy for iOS 17+
import Foundation
import Observation

@available(iOS 17, *)
@Observable
public final class ProxyKit: SecureProxyBase {}

public final class ProxyKitObservableObject: SecureProxyBase, ObservableObject {}
