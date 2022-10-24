# Privacy Gateway Client Demo Application

This sample application shows how to use the [app relay client](XXX) in a sample macOS application. It is meant for demonstration purposes only.

To build and run the application, the following steps must be followed.

1. Update the project's Library Search Paths to include the release build directory for the [app relay client](XXX), e.g., $(PROJECT_DIR)/relative/path/to/target/x86_64-apple-darwin/release.
2. Add SystemConfiguration.framework to the set of frameworks linked against the application. 
3. Add libohttp.dylib to the set of libraries linked against the application, where libohttp.dylib is in the app relay client release build.

Running the application should yield output similar to the following:

```
2022-07-29 10:34:16.499937-0400 app-relay-client[68817:5266282] Encapsulated request: {length = 57, bytes = 0x00002000 010001d2 0a57cf47 eea80214 ... 123c9ae8 1a856978 }
2022-07-29 10:34:16.707152-0400 app-relay-client[68817:5266895] Status(200), Content-Type(message/ohttp-res)
2022-07-29 10:34:16.707299-0400 app-relay-client[68817:5266895] Response: {length = 2, bytes = 0xcafe}
Program ended with exit code: 0
```
