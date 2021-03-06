//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include <TestFramework.h>
#import <Starboard/SmartTypes.h>
#import <Foundation/Foundation.h>
#import "UWP/WindowsUICore.h"
#import <UWP/WindowsDevicesGeolocation.h>
#import <UWP/WindowsServicesMaps.h>
#import <UWP/WindowsApplicationModel.h>

static const NSTimeInterval c_dispatchWaitTimeoutInSec = 60;

class ProjectionsDispatcherTest {
public:
    BEGIN_TEST_CLASS(ProjectionsDispatcherTest)
    END_TEST_CLASS()

    TEST_CLASS_SETUP(ProjectionTestClassSetup) {
        return FunctionalTestSetupUIApplication();
    }

    TEST_CLASS_CLEANUP(ProjectionTestCleanup) {
        return FunctionalTestCleanupUIApplication();
    }

    TEST_METHOD(WUCCoreDispatcherSanity) {
        LOG_INFO("Projection CoreDispatcher Sanity Test: ");

        ASSERT_FALSE_MSG([NSThread isMainThread], "Failed: Test cannot run on Main thread")

        __block dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        WUCDispatchedHandler dispatchedHandler = ^() {
            dispatch_semaphore_signal(semaphore);
        };

        __block StrongId<WUCCoreDispatcher> coreDispatcher;

        // Get the dispatcher for the main thread.
        // RunAsync needs to be called on the dispatcher for main thread.
        dispatch_sync(dispatch_get_main_queue(), ^{
            coreDispatcher = [[WUCCoreWindow getForCurrentThread] dispatcher];
        });

        [coreDispatcher runAsync:WUCCoreDispatcherPriorityNormal agileCallback:dispatchedHandler];
        long result =
            dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(c_dispatchWaitTimeoutInSec * NSEC_PER_SEC)));
        dispatch_release(semaphore);

        ASSERT_EQ_MSG(0, result, "FAILED: Test timed out, handler not called\n");
    }

    TEST_METHOD(AsyncOnBackgroundThread) {
        LOG_INFO("Validate callback on a background thread");
        __block bool callbackCalled = false;

        WDGBasicGeoposition* geoposition = [[WDGBasicGeoposition alloc] init];
        geoposition.latitude = 47.6381966;
        geoposition.longitude = -122.1313785;

        WDGGeopoint* geopoint = [WDGGeopoint make:geoposition];

        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        [WSMMapLocationFinder findLocationsAtAsync:geopoint
            success:^void(WSMMapLocationFinderResult* results) {
                callbackCalled = true;
                dispatch_group_leave(group);
            }
            failure:^void(NSError* error) {
                callbackCalled = true;
                dispatch_group_leave(group);
            }];

        dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(c_dispatchWaitTimeoutInSec * NSEC_PER_SEC)));
        dispatch_release(group);

        ASSERT_TRUE_MSG(callbackCalled, "FAILED: Test timed out before callback was invoked.\n");
    }
};
