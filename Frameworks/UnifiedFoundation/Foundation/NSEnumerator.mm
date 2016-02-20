//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
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

#import "Starboard.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSMutableArray.h"
#import "NSEnumeratorInternal.h"

// Abstract NSEnumerator superclass
@implementation NSEnumerator

/**
 @Status Interoperable
*/
- (NSArray*)allObjects {
    NSMutableArray* ret = [NSMutableArray new];

    id cur = [self nextObject];
    while (cur != nil) {
        [ret addObject:cur];
        cur = [self nextObject];
    }

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (NSObject*)nextObject {
    [NSException raise:NSInternalInconsistencyException format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

/**
 @Status Interoperable
*/
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackBuf count:(NSUInteger)maxCount {
    if (state->state == 0) {
        // legacy code best guess:
        // NSEnumerator has a general assumption that the underlying collection should not mutate during enumeration
        // mutationPtr, which is intended to signal mutations, should then point to a stable value
        // choose extra[1], which is not touched
        state->mutationsPtr = (unsigned long*)&state->extra[1];

        state->extra[0] = (unsigned long)self;
        state->state = 1;
    }
    assert(maxCount > 0);

    NSUInteger numRet = 0;
    state->itemsPtr = (id*)stackBuf;

    while (maxCount > 0) {
        id next = [reinterpret_cast<id>(state->extra[0]) nextObject];
        if (next == nil) {
            break;
        }

        *stackBuf = next;
        stackBuf++;
        numRet++;
        maxCount--;
    }

    return numRet;
}

@end

// Subclass of NSEnumerator for classes that can provide its contents as an array
@interface _NSArrayEnumerator : NSEnumerator
- (instancetype)initWithArray:(NSArray*)array currentIndex:(int)curIndex iterateForwards:(BOOL)iterateForwards;
@end

@implementation _NSArrayEnumerator {
@private
    NSArray* _objArray; // unsafe unretained
    int _curIndex;
    BOOL _iterateForwards;
}

- (instancetype)initWithArray:(NSArray*)array currentIndex:(int)curIndex iterateForwards:(BOOL)iterateForwards {
    if (self = [super init]) {
        _objArray = array;
        _curIndex = curIndex;
        _iterateForwards = iterateForwards;
    }

    return self;
}

- (NSObject*)nextObject {
    if (_iterateForwards) {
        int count = [_objArray count];

        if (_curIndex >= count) {
            return nil;
        }

        NSObject* ret = [_objArray objectAtIndex:_curIndex];
        _curIndex++;

        return ret;

    } else {
        if (_curIndex < 0) {
            return nil;
        }

        NSObject* ret = [_objArray objectAtIndex:_curIndex];
        _curIndex--;

        return ret;
    }
}

@end

// Subclass of NSEnumerator for use with iterator functions
@interface _NSIteratorEnumerator : NSEnumerator
- (instancetype)initWithIterator:(initIteratorFunc)initIterator forObject:(id)obj nextFunction:(nextValueFunc)nextValueFunction;
@end

@implementation _NSIteratorEnumerator {
@private
    NSUInteger _iteratorState[5];
    nextValueFunc _getNextValueFunction;
    id _iteratorObj; // unsafe unretained
}

- (instancetype)initWithIterator:(initIteratorFunc)initIterator forObject:(id)obj nextFunction:(nextValueFunc)nextValueFunction {
    if (self = [super init]) {
        _getNextValueFunction = nextValueFunction;
        _iteratorObj = obj;
        initIterator(obj, _iteratorState);
    }

    return self;
}

- (NSObject*)nextObject {
    id ret;
    int count = _getNextValueFunction(_iteratorObj, _iteratorState, &ret, 1);
    if (count == 1) {
        return ret;
    }

    return nil;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackBuf count:(NSUInteger)maxCount {
    if (state->state == 0) {
        state->state = 1;
        state->mutationsPtr = (unsigned long*)(&state->state);
    }

    assert(maxCount > 0);

    state->itemsPtr = (id*)stackBuf;
    int ret = _getNextValueFunction(_iteratorObj, _iteratorState, stackBuf, maxCount);

    return ret;
}
@end

// Utilities category
@implementation NSEnumerator (Utilities)

+ (NSEnumerator*)enumeratorWithArray:(NSArray*)array {
    return [[[_NSArrayEnumerator alloc] initWithArray:array currentIndex:0 iterateForwards:YES] autorelease];
}

+ (NSEnumerator*)enumeratorWithArrayReverse:(NSArray*)array {
    return [[[_NSArrayEnumerator alloc] initWithArray:array currentIndex:([array count] - 1) iterateForwards:NO] autorelease];
}

+ (NSEnumerator*)enumeratorWithIterator:(initIteratorFunc)initIterator forObject:(id)obj nextFunction:(nextValueFunc)nextValueFunction {
    return [[[_NSIteratorEnumerator alloc] initWithIterator:initIterator forObject:obj nextFunction:nextValueFunction] autorelease];
}

@end
