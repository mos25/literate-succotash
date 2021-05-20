// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import XCTest

class FBSDKBridgeAPIProtocolWebV1Tests: FBSDKTestCase {

  enum Keys {
    static let actionID = "action_id"
    static let bridgeArgs = "bridge_args"
    static let completionGesture = "completionGesture"
    static let didComplete = "didComplete"
    static let display = "display"
    static let errorCode = "error_code"
    static let redirectURI = "redirect_uri"
  }

  enum Values {
    static let actionID = "123"
    static let cancel = "cancel"
    static let cancellationErrorCode = 4201
    static let methodName = "open"
    static let methodVersion = "v1"
    static let redirectURI = "fb://bridge/open?bridge_args=%7B%22action_id%22%3A%22123%22%7D"
    static let scheme = "https"
    static let touch = "touch"
    static let unknownErrorCode = 12345
  }

  enum QueryParameters {
    static let withoutBridgeArgs: [String: Any] = [:]
    static let withEmptyBridgeArgs: [String: Any] = [Keys.bridgeArgs: ""]
    static let valid = withBridgeArgs(responseActionID: Values.actionID)

    // swiftlint:disable force_try force_unwrapping
    static func jsonString(actionID: String) -> String {
      let data = try! JSONSerialization.data(
        withJSONObject: [Keys.actionID: actionID], options: []
      )
      return String(data: data, encoding: .utf8)!
    }
    // swiftlint:enable force_try force_unwrapping

    static func withBridgeArgs(responseActionID: String) -> [String: Any] {
      return [Keys.bridgeArgs: jsonString(actionID: responseActionID)]
    }

    static func validWithErrorCode(_ code: Int) -> [String: Any] {
      return [
        Keys.errorCode: code,
        Keys.bridgeArgs: jsonString(actionID: Values.actionID)
      ]
    }
  }

  let bridge = BridgeAPIProtocolWebV1()

  func testCreatingURLWithoutInputs() {
    XCTAssertNil(
      try? bridge.requestURL(
        withActionID: nil,
        scheme: nil,
        methodName: nil,
        methodVersion: nil,
        parameters: nil
      ),
      "Should not create a url without a method name or an action ID"
    )
  }

  func testCreatingURLWithoutActionID() {
    XCTAssertNil(
      try? bridge.requestURL(
        withActionID: nil,
        scheme: Values.scheme,
        methodName: Values.methodName,
        methodVersion: Values.methodVersion,
        parameters: QueryParameters.withEmptyBridgeArgs
      ),
      "Should not create a url without action ID"
    )
  }

  func testCreatingURLWithoutMethodName() {
    XCTAssertNil(
      try? bridge.requestURL(
        withActionID: Values.actionID,
        scheme: Values.scheme,
        methodName: nil,
        methodVersion: Values.methodVersion,
        parameters: QueryParameters.withEmptyBridgeArgs
      ),
      "Should not create a url without a method name"
    )
  }

  func testCreatingURLWithAllFields() {
    guard let url = try? bridge.requestURL(
      withActionID: Values.actionID,
      scheme: Values.scheme,
      methodName: Values.methodName,
      methodVersion: Values.methodVersion,
      parameters: QueryParameters.valid
    )
    else {
      return XCTFail("Should create a valid url when an action ID is provided")
    }

    XCTAssertEqual(
      url.host,
      "m.facebook.com",
      "Should create a url with the expected host"
    )
    XCTAssertEqual(
      url.path,
      "/\(Settings.graphAPIVersion!)/dialog/open", // swiftlint:disable:this force_unwrapping
      "Should create a url with the expected path"
    )
    guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    else {
      return XCTFail("Should have query items")
    }
    [
      URLQueryItem(name: Keys.bridgeArgs, value: QueryParameters.jsonString(actionID: Values.actionID)),
      URLQueryItem(name: Keys.display, value: Values.touch),
      URLQueryItem(name: Keys.redirectURI, value: Values.redirectURI)
    ].forEach { queryItem in
      XCTAssertTrue(
        queryItems.contains(queryItem)
      )
    }
  }

  func testResponseParametersWithUnknownErrorCode() {
    XCTAssertNil(
      try? bridge.responseParameters(
        forActionID: Values.actionID,
        queryParameters: QueryParameters.validWithErrorCode(123),
        cancelled: nil
      ),
      "Should not create response parameters when there is an unknown error code"
    )
  }

  func testResponseParametersWithoutBridgeParameters() {
    XCTAssertNil(
      try? bridge.responseParameters(
        forActionID: Values.actionID,
        queryParameters: QueryParameters.withoutBridgeArgs,
        cancelled: nil
      ),
      "Should not create response parameters when there are no bridge arguments"
    )
  }

  func testResponseParametersWithoutActionID() {
    XCTAssertNil(
      try? bridge.responseParameters(
        forActionID: Values.actionID,
        queryParameters: QueryParameters.withEmptyBridgeArgs,
        cancelled: nil
      ),
      "Should not create response parameters when there is no action id"
    )
  }

  func testResponseParametersWithMismatchedResponseActionID() {
    XCTAssertNil(
      try? bridge.responseParameters(
        forActionID: Values.actionID,
        queryParameters: QueryParameters.withBridgeArgs(responseActionID: "foo"),
        cancelled: nil
      ),
      "Should not create response parameters when the action IDs do not match"
    )
  }

  func testResponseParametersWithMatchingResponseActionID() {
    guard let response = try? bridge.responseParameters(
      forActionID: Values.actionID,
      queryParameters: QueryParameters.valid,
      cancelled: nil
    ) else {
      return XCTFail("Should create a valid response")
    }

    XCTAssertEqual(
      response as? [String: Int],
      [Keys.didComplete: 1],
      "Should indicate that the response completed"
    )
  }

  func testResponseParametersWithCancellationErrorCode() {
    guard let response = try? bridge.responseParameters(
      forActionID: Values.actionID,
      queryParameters: QueryParameters.validWithErrorCode(Values.cancellationErrorCode),
      cancelled: nil
    ) else {
      return XCTFail("Should create a valid response")
    }

    XCTAssertEqual(
      response as? [String: String],
      [Keys.completionGesture: Values.cancel],
      "Should indicate a cancelation when there's a cancellation error code"
    )
  }
}
