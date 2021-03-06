/* Copyright 2016 Esteve Fernandez <esteve@apache.org>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdio.h>
#include "rcl/error_handling.h"
#include "rcl/node.h"
#include "rcl/rcl.h"
#include "rmw/rmw.h"

#import "rclobjc/ROSClient.h"

@interface FunctionPointerContainer ()

@property(assign) FunctionPointer funtionPointer;

@end

@implementation FunctionPointerContainer

@synthesize funtionPointer;

- (instancetype)initWithArguments: (FunctionPointer)init_funtionPointer {
    self.funtionPointer = init_funtionPointer;
    return self;
}

- (FunctionPointer)getFunctionPointer {
    return self.funtionPointer;
}
@end



@interface ROSClient ()

@property(assign) intptr_t nodeHandle;
@property(assign) intptr_t clientHandle;
@property(assign) Class serviceType;
@property(assign) NSString *serviceName;
@property(assign) Class requestType;
@property(assign) Class responseType;
@property(assign)
    NSMutableDictionary<NSNumber *, FunctionPointerContainer *> *pendingRequests;

@end

@implementation ROSClient

@synthesize nodeHandle;
@synthesize clientHandle;
@synthesize serviceType;
@synthesize serviceName;
@synthesize requestType;
@synthesize responseType;
@synthesize pendingRequests;

- (instancetype)initWithArguments:(intptr_t)
                       nodeHandle:(intptr_t)
                     clientHandle:(Class)
                      serviceType:(NSString *)serviceName {
  self.nodeHandle = nodeHandle;
  self.clientHandle = clientHandle;
  self.serviceType = serviceType;
  self.serviceName = serviceName;
  self.requestType = [serviceType requestType];
  self.responseType = [serviceType responseType];
  self.pendingRequests = [[NSMutableDictionary alloc] init];

  assert(clientHandle != 0);

  return self;
}

- (void)sendRequest:(id)request:(void (*)(id))callback {
  rcl_client_t *client = (rcl_client_t *)self.clientHandle;

  typedef void *(*convert_from_objc_signature)(NSObject *);

  intptr_t requestFromObjcConverterHandle =
      [self.requestType fromObjcConverterPtr];

  convert_from_objc_signature convert_request_from_objc =
      (convert_from_objc_signature)requestFromObjcConverterHandle;

  void *ros_request_msg = convert_request_from_objc(request);

  int64_t sequence_number = 0;
  rcl_ret_t ret = rcl_send_request(client, ros_request_msg, &sequence_number);

  int key = [NSNumber numberWithInteger:sequence_number];

  [self.pendingRequests setObject:[[FunctionPointerContainer alloc] initWithArguments :callback]
                           forKey:key];

  assert(ret == RCL_RET_OK);
}

- (void)handleResponse:(int64_t)sequenceNumber:(id)response {
  NSNumber *nsseq = [NSNumber numberWithInteger:sequenceNumber];

  void (*callback)(id) = [[self.pendingRequests objectForKey:nsseq] getFunctionPointer];
  [self.pendingRequests removeObjectForKey:nsseq];
  callback(response);
}

- (void)dispose{
  intptr_t node_handle = self.nodeHandle;
  intptr_t client_handle = self.clientHandle;


  if (client_handle == 0) {
    // everything is ok, already destroyed
    return;
  }

  if (node_handle == 0) {
    // TODO(esteve): handle this, node is null, but client isn't
    return;
  }

  rcl_node_t * node = (rcl_node_t *)node_handle;

  assert(node != NULL);

  rcl_client_t * client = (rcl_client_t *)client_handle;

  assert(client != NULL);

  rcl_ret_t ret = rcl_client_fini(client, node);

  if (ret != RCL_RET_OK) {
    NSLog(@"Failed to destroy client: %s", rcl_get_error_string_safe());
    rcl_reset_error();
  }

  self.nodeHandle = 0;
}

@end
