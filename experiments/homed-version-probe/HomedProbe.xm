#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import <os/log.h>
#include <sys/sysctl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// A separate, opt-in experiment. It never alters the on-disk Apple binaries.
// ElleKit exports the Substrate-compatible in-memory patch primitive.
extern "C" void MSHookMemory(void *target, const void *data, size_t size);
extern "C" void MSHookMessageEx(Class cls, SEL selector, IMP hook, IMP *original);

static BOOL (*sOriginalCanPair)(id, SEL, unsigned long long) = nullptr;
static BOOL sCapabilityHookInstalled = NO;
static dispatch_once_t sCapabilityScheduleOnce;

// Only the optional experimental homed package enables this adapter. It is
// restricted to unassociated Apple media accessories with the observed
// iOS 16.1.1 capability mask 0x3. Paired accessories and unrelated HomeKit
// pairing classes continue through Apple's unmodified implementation.
static BOOL HPBExperimentalCanPair(id accessory, SEL selector,
                                   unsigned long long availableCapabilities) {
    BOOL original = sOriginalCanPair
        ? sOriginalCanPair(accessory, selector, availableCapabilities)
        : NO;

    uint64_t required = 0;
    BOOL hasRequiredMask = NO;
    SEL requiredSelector = sel_registerName("requiredPairingCapabilities");
    Method requiredMethod = class_getInstanceMethod(object_getClass(accessory), requiredSelector);
    if (requiredMethod) {
        char *returnType = method_copyReturnType(requiredMethod);
        if (returnType && strchr("QqIiLlSsCcB", returnType[0])) {
            // Inspect Apple's actual mask. Avoid invoking an accessor with
            // unexpected object/struct return ABI.
            IMP implementation = method_getImplementation(requiredMethod);
            required = ((uint64_t (*)(id, SEL))implementation)(accessory, requiredSelector);
            hasRequiredMask = YES;
        }
        if (returnType) free(returnType);
    }

    Class appleMedia = objc_getClass("HMDUnassociatedAppleMediaAccessory");
    // HomePod-specific receiver classes can inherit this implementation.
    // Requiring exact class equality would miss those subclasses.
    BOOL targeted = appleMedia && [accessory isKindOfClass:appleMedia] &&
                    availableCapabilities == 0x3;

    // The only forced result in this opt-in package. If Apple already allows
    // pairing or another accessory class is involved, do not alter its answer.
    BOOL override = targeted && !original;
    os_log_error(OS_LOG_DEFAULT,
                 "[HomePodBridge homed-probe 0.1.7] capability gate: offered=0x%{public}llx required=0x%{public}llx known=%{public}d original=%{public}d override=%{public}d class=%{public}s",
                 availableCapabilities, (unsigned long long)required,
                 hasRequiredMask, original, override,
                 class_getName(object_getClass(accessory)));
    return original || override;
}

// homed need not drain the main dispatch queue while its device-setup session
// is active. Use a daemon-independent queue and retry briefly if Objective-C
// has not registered HomeKitDaemon's classes when dyld reports the image.
static void HPBInstallCapabilityHook(unsigned attempt) {
    if (sCapabilityHookInstalled) return;
    Class cls = objc_getClass("HMDUnassociatedAppleMediaAccessory");
    SEL selector = sel_registerName("canPairGivenCapabilities:");
    if (!cls || !class_getInstanceMethod(cls, selector)) {
        os_log_error(OS_LOG_DEFAULT,
                     "[HomePodBridge homed-probe 0.1.7] capability hook not ready; attempt=%{public}u class=%{public}d",
                     attempt + 1, cls != Nil);
        if (attempt < 11) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC),
                           dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                HPBInstallCapabilityHook(attempt + 1);
            });
        } else {
            os_log_error(OS_LOG_DEFAULT,
                         "[HomePodBridge homed-probe 0.1.7] capability hook unavailable after retries; Apple predicate unchanged");
        }
        return;
    }
    MSHookMessageEx(cls, selector, (IMP)HPBExperimentalCanPair,
                    (IMP *)&sOriginalCanPair);
    sCapabilityHookInstalled = sOriginalCanPair != nullptr;
    os_log_error(OS_LOG_DEFAULT,
                 "[HomePodBridge homed-probe 0.1.7] Apple-media capability hook installed=%{public}d after_attempt=%{public}u",
                 sCapabilityHookInstalled, attempt + 1);
}

struct HPBVersionProbeTarget {
    const char *pathSuffix;
    uintptr_t unslidInstructionAddress;
    const uint8_t *expected;
    size_t expectedLength;
    size_t branchInstructionOffset;
};

// New HomeKitDaemon: BL isAtLeastVersion: followed by STR w0, [sp, #0x14].
// Replacing only that BL with MOV w0, #1 preserves the separate
// canPairGivenCapabilities: test performed at +0x1fdb915ec.
// iOS 16.1.1 / iPhone14,3 / 20B101 dyld shared cache, verified in disassembly.
static const uint8_t kModernSignature[] = {
    0xe0,0x03,0x14,0xaa, // mov x0, x20
    0xe2,0x03,0x1a,0xaa, // mov x2, x26
    0x17,0x54,0x2f,0x94, // bl objc_msgSend$isAtLeastVersion:
    0xe0,0x17,0x00,0xb9  // str w0, [sp,#0x14]
};

// Legacy framework: BL isAtLeastVersion: followed by MOV x21, x0.
// Its canPairGivenCapabilities: result is still ANDed with that flag.
static const uint8_t kLegacySignature[] = {
    0xe0,0x03,0x14,0xaa, // mov x0, x20
    0xe2,0x03,0x1c,0xaa, // mov x2, x28
    0x2b,0xdd,0x2a,0x94, // bl objc_msgSend$isAtLeastVersion:
    0xf5,0x03,0x00,0xaa  // mov x21, x0
};

static const uint8_t kMoveTrueToW0[] = { 0x20,0x00,0x80,0x52 };

static const HPBVersionProbeTarget kTargets[] = {
    { "/HomeKitDaemon.framework/HomeKitDaemon", 0x1fdb9151c,
      kModernSignature, sizeof(kModernSignature), 8 },
    { "/HomeKitDaemonLegacy.framework/HomeKitDaemonLegacy", 0x1c433d60c,
      kLegacySignature, sizeof(kLegacySignature), 8 }
};

static bool HPBHasMatchingFirmware(void) {
    NSOperatingSystemVersion os = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (os.majorVersion != 16 || os.minorVersion != 1 || os.patchVersion != 1) {
        return false;
    }
    char version[64] = {};
    size_t length = sizeof(version);
    if (sysctlbyname("kern.osversion", version, &length, nullptr, 0) != 0) {
        return false;
    }
    return strcmp(version, "20B101") == 0;
}

static bool HPBHasSuffix(const char *string, const char *suffix) {
    if (!string || !suffix) return false;
    const size_t left = strlen(string);
    const size_t right = strlen(suffix);
    return left >= right && strcmp(string + left - right, suffix) == 0;
}

static void HPBCheckImage(const struct mach_header *header, intptr_t slide) {
    if (!header || header->magic != MH_MAGIC_64 || header->filetype != MH_DYLIB) {
        return;
    }
    const char *name = nullptr;
    const uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; ++i) {
        if (_dyld_get_image_header(i) == header) {
            name = _dyld_get_image_name(i);
            break;
        }
    }
    if (!name) return;

    for (const HPBVersionProbeTarget &target : kTargets) {
        if (!HPBHasSuffix(name, target.pathSuffix)) continue;
        const uintptr_t actualAddress = target.unslidInstructionAddress + (uintptr_t)slide;
        const uintptr_t expectedAddress = actualAddress;
        const uint8_t *current = reinterpret_cast<const uint8_t *>(expectedAddress);
        if (memcmp(current, target.expected, target.expectedLength) != 0) {
            NSLog(@"[HomePodBridge homed-probe] Refusing unmatched image: %s", name);
            return;
        }

        uint8_t *instruction = reinterpret_cast<uint8_t *>(actualAddress + target.branchInstructionOffset);
        MSHookMemory(instruction, kMoveTrueToW0, sizeof(kMoveTrueToW0));
        if (memcmp(instruction, kMoveTrueToW0, sizeof(kMoveTrueToW0)) == 0) {
            os_log_error(OS_LOG_DEFAULT,
                         "[HomePodBridge homed-probe 0.1.7] minimum-version patch verified; image=%{public}s; scheduling capability hook",
                         name);
            // Do not call MSHookMessageEx under dyld's image-load lock.
            dispatch_once(&sCapabilityScheduleOnce, ^{
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    HPBInstallCapabilityHook(0);
                });
            });
        } else {
            NSLog(@"[HomePodBridge homed-probe] FAILED to patch %s", name);
        }
        return;
    }
}

__attribute__((constructor)) static void HPBInitializeProbe(void) {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        if (![processName isEqualToString:@"homed"]) return;
        if (!HPBHasMatchingFirmware()) {
            NSLog(@"[HomePodBridge homed-probe] Refusing: requires iOS 16.1.1 build 20B101");
            return;
        }
        os_log_error(OS_LOG_DEFAULT,
                     "[HomePodBridge homed-probe 0.1.7] loaded in homed; waiting for matching HomeKit framework image");
        // dyld invokes this callback for already loaded images and future images.
        _dyld_register_func_for_add_image(HPBCheckImage);
    }
}
