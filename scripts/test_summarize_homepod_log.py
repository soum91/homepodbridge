import importlib.util
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).with_name("summarize-homepod-log.py")
SPEC = importlib.util.spec_from_file_location("summarize_homepod_log", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SummarizerTests(unittest.TestCase):
    def test_phase_order_and_privacy(self):
        log = [
            "2026-11-07 17:00:00 HDSViewService: [HomePodBridge 0.1.4] Initialized\n",
            "2026-11-07 17:00:01 HDSViewService: [HomePodBridge] Patched unknown-device update gate at +0x82318\n",
            "2026-11-07 17:00:02 HDSViewService: PreAuth response: {serial=SECRET123, token=SECRET456}\n",
            "2026-11-07 17:02:05 HDSViewService: kHomeKitSyncTimeoutErr (HomeKitSetupWaitDeviceSetup)\n",
        ]
        events = MODULE.summarize(log)
        self.assertEqual([label for _, label in events], [
            "tweak_loaded", "patch_applied", "preauth_complete", "homekit_wait_timeout"
        ])
        self.assertNotIn("SECRET", str(events))

    def test_old_gate_without_patch(self):
        events = MODULE.summarize([
            "2026-11-07 16:30:00 HDSViewService: Requires an upgrade because device 11 is not known."
        ])
        self.assertEqual(events[0][1], "legacy_unknown_device")


if __name__ == "__main__":
    unittest.main()
