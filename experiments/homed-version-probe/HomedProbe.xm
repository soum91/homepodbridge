#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <sys/sysctl.h>
#include <stdint.h>
#include <string.h>

// A separate, opt-in experiment. It never alters the on-disk Apple binaries.
// ElleKit exports the Substrate-compatible in-memory patch primitive.
extern "C" void MSHookMemory(void *target, const void *data, size_t size);

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
            NSLog(@"[HomePodBridge homed-probe] Version-only comparison patched for %s; capability predicate is untouched", name);
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
        NSLog(@"[HomePodBridge homed-probe 0.1.5-probe1] Waiting for matching HomeKit framework image");
        // dyld invokes this callback for already loaded images and future images.
        _dyld_register_func_for_add_image(HPBCheckImage);
    }
}
