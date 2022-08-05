// Copyright (c) 2022 Cloudflare, Inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>

// Note: this must be referenced from the corresponding library:
//   https://github.com/cloudflare/app-relay-client-library
// See README.md for more instructions on configuring and building this application.
#import "apprelay.h"

// Import the protobuf HTTP types. The definition for the protobuf-based HTTP encoding
// is located here:
//   https://github.com/cloudflare/app-relay-gateway-go/blob/main/proto_http.proto
// See the following for information about how to build the protobuf runtime and include
// in this project for correct function:
//   https://developers.google.com/protocol-buffers/docs/reference/objective-c-generated
//#import "ProtoHTTP.pbobjc.h"

int main(int argc, const char * argv[]) {
    // Note: this is fetched directly from the target.
    const uint8_t encoded_config[] = {
        /* Initialize this based on the configuration from the server */
    };
    size_t encoded_config_len = sizeof(encoded_config);
    
    // This is the following HTTP/1.1 request:
    //
    //    GET /index.html HTTP/1.1
    //    User-Agent: curl/7.16.3 libcurl/7.16.3 OpenSSL/0.9.7l zlib/1.2.3
    //    Host: www.neverssl.com
    //    Accept-Language: en, mi
    //
    Request *request = [[Request alloc] init];
    [request setMethod:Request_Method_Get];
    [request setScheme:Request_Scheme_HTTP];
    [request setAuthority:@"www.neverssl.com"];
    [request setPath:@"/"];
    
    NSData *requestData = [request data];
    const uint8_t *encoded_msg = [requestData bytes];
    uint8_t encoded_msg_len = [requestData length];
        
    // Encapsulate the binary-encoded HTTP message.
    struct RequestContext *context = encapsulate_request_ffi(encoded_config, encoded_config_len, encoded_msg, encoded_msg_len);
    if (context == NULL) {
        NSLog(@"Failure");
    } else {
        const uint8_t *message = (const uint8_t *)request_context_message_ffi(context);
        size_t message_len = (size_t)request_context_message_len_ffi(context);
        NSData *requestBody = [[NSData alloc] initWithBytes:message length:message_len];
        NSLog(@"Encapsulated request: %@", [[NSString stringWithFormat:@"%@", requestBody] description]);

        // Construct the request for relaying the encapsulated request
        NSString *gatewayURL = @"FILL ME IN";
        NSURL *url = [NSURL URLWithString:gatewayURL];
        NSURLSession *session = [NSURLSession sharedSession];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request addValue:@"message/ohttp-req" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:requestBody];

        // Send the encapsulated request to the app relay
        dispatch_semaphore_t signal = dispatch_semaphore_create(0);
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable urlResponse, NSError * _Nullable error) {
            if (error == nil) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlResponse;
                NSLog(@"Status(%ld), Content-Type(%@)", [httpResponse statusCode], [httpResponse valueForHTTPHeaderField:@"Content-Type"]);
                
                if ([httpResponse statusCode] == 200 && [[httpResponse valueForHTTPHeaderField:@"Content-Type"] isEqual:@"message/ohttp-res"]) {
                    // Copy and decapsulate the encapsulated response
                    const uint8_t *encapsulated_response = [data bytes];
                    size_t encapsulated_response_len = [data length];
                    struct ResponseContext *response_context = decapsulate_response_ffi(context, encapsulated_response, encapsulated_response_len);
                    
                    if (response_context != NULL) {
                        const uint8_t *response_bytes = (const uint8_t *)response_context_message_ffi(response_context);
                        size_t response_len = (size_t)response_context_message_len_ffi(response_context);
                        NSData *responseData = [[NSData alloc] initWithBytes:response_bytes length:response_len];
                        
                        // Decode and display the final response
                        NSError *error = nil;
                        Response *response = [[Response alloc] initWithData:responseData error:&error];
                        if (error == nil) {
                            NSLog(@"%@", [[NSString alloc] initWithData:[response body] encoding:NSASCIIStringEncoding]);
                        }
                    } else {
                        NSLog(@"Decapsulation failed");
                    }
                }
            } else {
                NSLog(@"Request failed: %@", [error description]);
            }
            dispatch_semaphore_signal(signal);
        }];
        [task resume];
        dispatch_semaphore_wait(signal, dispatch_time(DISPATCH_TIME_NOW, (5 * NSEC_PER_SEC)));
    }
    return 0;
}
