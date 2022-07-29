// Copyright (c) 2022 Cloudflare, Inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>

// Note: this must be referenced from the corresponding library:
//   https://github.com/cloudflare/app-relay-client-library
// See README.md for more instructions on configuring and building this application.
#import "apprelay.h"

int main(int argc, const char * argv[]) {
    // Note: this is fetched directly from the target.
    const uint8_t encoded_config[] = {0x00, 0x00, 0x20, 0xae, 0x64, 0xc6, 0xa9, 0x09, 0xa9, 0x00, 0xe9, 0xef, 0x61, 0x6b, 0xce, 0xd2, 0xa0, 0x5f, 0xcf, 0xf2, 0x26, 0x99, 0xdb, 0x9d, 0x98, 0x83, 0xa0, 0x8c, 0x20, 0xd6, 0x2a, 0x43, 0x44, 0xe7, 0x29, 0x00, 0x04, 0x00, 0x01, 0x00, 01};
    size_t encoded_config_len = sizeof(encoded_config);
    
    // This is the binary-encoded HTTP message to be encapsulated. For this
    // sample code, the message is not actually a valid binary HTTP message.
    const uint8_t encoded_msg[] = {0xCA, 0xFE};
    size_t encoded_msg_len = sizeof(encoded_msg);
    
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
        NSURL *url = [NSURL URLWithString:@"<insert target or relay URL here>"];
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
                
                if ([httpResponse statusCode] == 200) {
                    // Copy and decapsulate the encapsulated response
                    const uint8_t *encapsulated_response = [data bytes];
                    size_t encapsulated_response_len = [data length];
                    struct ResponseContext *response_context = decapsulate_response_ffi(context, encapsulated_response, encapsulated_response_len);
                    
                    if (response_context != NULL) {
                        // Copy out the final response and print it for debug purposes.
                        const uint8_t *response = (const uint8_t *)response_context_message_ffi(response_context);
                        size_t response_len = (size_t)response_context_message_len_ffi(response_context);
                        NSData *responseData = [[NSData alloc] initWithBytes:response length:response_len];
                        NSLog(@"Response: %@", [[NSString stringWithFormat:@"%@", responseData] description]);
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
