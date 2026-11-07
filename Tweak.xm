#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <stdint.h>
#include <string.h>

// ElleKit implements the Substrate-compatible memory patch API.
extern "C" void MSHookMemory(void *target, const void *data, size_t size);

// Analysis of the original iOS 16.1.1 HDSViewService executable:
// SHA-256: 0ef19ac608379b89fc0eb93f190c5b4253ede0b88f44bf72e8f7ee0206e5eb91
// Image __TEXT base: 0x100000000
// At +0x82310, the original instructions are:
//   cmp w8, #0
//   ccmp w8, #5, #4, ne
//   b.ne 0x100082324     <-- reject previously unknown device types
//   mov w0, #0           <-- accept/continue setup
//   b 0x1000823c8       <-- return
// A single NOP at +0x82318 preserves existing accepted values and redirects
// other device types, including HomePod mini 2's type 11, to the normal success
// return. This is a protocol-compatibility experiment, not a verified fix.

static constexpr uintptr_t kBranchOffset = 0x82318;
static constexpr uintptr_t kSignatureOffset = 0x82310;

static const uint8_t kOriginalInstructions[20] = {
    0x1f, 0x01, 0x00, 0x71, // cmp w8, #0
    0x04, 0x19, 0x45, 0x7a, // ccmp w8, #5, #4, ne
    0x61, 0x00, 0x00, 0x54, // b.ne #12
    0x00, 0x00, 0x80, 0x52, // mov w0, #0
    0x2a, 0x00, 0x00, 0x14, // b #168
};

static const uint8_t kNopInstruction[4] = { 0x1f, 0x20, 0x03, 0xd5 };

static NSString *HPBridgeHexBytes(const uint8_t *bytes, size_t count) {
    NSMutableString *hex = [NSMutableString stringWithCapacity:count * 3];
    for (size_t i = 0; i < count; ++i) {
        if (i) [hex appendString:@" "];
        [hex appendFormat:@"%02x", (unsigned int)bytes[i]];
    }
    return hex;
}

static void HPBridgeApplyPatch(void) {
    @autoreleasepool {
        NSLog(@"[HomePodBridge 0.1.3] Initialized");
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleID isEqualToString:@"com.apple.HDSViewService"]) {
            return;
        }

        NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        if (![bundleVersion isEqualToString:@"24"]) {
            NSLog(@"[HomePodBridge] Refusing to patch unexpected HDSViewService build %@", bundleVersion);
            return;
        }

        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        if (version.majorVersion != 16 || version.minorVersion != 1) {
            NSLog(@"[HomePodBridge] Refusing to patch unexpected iOS version %ld.%ld", (long)version.majorVersion, (long)version.minorVersion);
            return;
        }

        const struct mach_header *header = _dyld_get_image_header(0);
        if (!header || header->magic != MH_MAGIC_64) {
            NSLog(@"[HomePodBridge] Refusing to patch invalid main executable header");
            return;
        }

        uint8_t *base = (uint8_t *)(uintptr_t)header;
        uint8_t *signature = base + kSignatureOffset;
        if (memcmp(signature, kOriginalInstructions, sizeof(kOriginalInstructions)) != 0) {
            const char *imageName = _dyld_get_image_name(0);
            NSLog(@"[HomePodBridge] Refusing to patch: instruction signature mismatch at image +0x%lx; image=%s",
                  (unsigned long)kSignatureOffset, imageName ? imageName : "(unknown)");
            NSLog(@"[HomePodBridge] Live instructions: %@", HPBridgeHexBytes(signature, sizeof(kOriginalInstructions)));
            NSLog(@"[HomePodBridge] Expected instructions: %@", HPBridgeHexBytes(kOriginalInstructions, sizeof(kOriginalInstructions)));
            return;
        }

        uint8_t *target = base + kBranchOffset;
        MSHookMemory(target, kNopInstruction, sizeof(kNopInstruction));
        if (memcmp(target, kNopInstruction, sizeof(kNopInstruction)) == 0) {
            NSLog(@"[HomePodBridge] Patched unknown-device update gate at +0x%lx", (unsigned long)kBranchOffset);
        } else {
            NSLog(@"[HomePodBridge] FAILED to patch unknown-device update gate");
        }
    }
}

__attribute__((constructor)) static void HPBridgeInitialize(void) {
    HPBridgeApplyPatch();
}
