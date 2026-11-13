#!/usr/bin/env python3
import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
import sys
import json
import plistlib
import tempfile
import threading

sys.dont_write_bytecode = True
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'home/.local/libexec/sketchibar-update'

class DataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not HELPER.is_file():
            return
        loader = importlib.machinery.SourceFileLoader('strip_data', str(HELPER))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        cls.data = importlib.util.module_from_spec(spec)
        loader.exec_module(cls.data)

    def setUp(self):
        self.assertTrue(HELPER.is_file(), 'missing live-data helper')

    def test_battery_discharging_and_charging(self):
        for status, expected in [('discharging; 3:20 remaining', '3h 20m'),
                                 ('charging; 1:05 remaining', '↑ 1h 05m'),
                                 ('charged; 0:00 remaining', '—'),
                                 ('AC attached; not charging; 0:00 remaining', '—')]:
            result = self.data.battery("Now drawing from 'AC Power'\n -InternalBattery-0\t82%; " + status)
            self.assertEqual(result['sketchibar.battery.level']['label'], '82%')
            self.assertEqual(result['sketchibar.battery.time']['label'], expected)
            self.assertEqual(result['sketchibar.battery.time']['drawing'], 'off' if expected == '—' else 'on')
        unknown = self.data.battery('no battery')
        self.assertEqual(unknown['sketchibar.battery.level']['label'], '—')
        self.assertEqual(self.data.battery('82%; discharging; (no estimate)')['sketchibar.battery.time']['label'], '—')

    def forecast(self):
        return {'current': {'time': '2026-11-12T19:45', 'temperature_2m': 18,
                            'apparent_temperature': 17, 'weather_code': 0, 'is_day': 0,
                            'wind_speed_10m': 3.2},
                'daily': {'time': ['2026-11-12'], 'temperature_2m_min': [12],
                          'temperature_2m_max': [21]},
                'hourly': {'time': ['2026-11-12T18:00', '2026-11-12T19:00'],
                           'precipitation_probability': [10, 30]}}

    def test_weather_values_and_current_hour_probability(self):
        result = self.data.weather(self.forecast())
        labels = [v['label'] for v in result.values()]
        for label in ('18° (17°)', '12°', '21°', '30%', '3.2m/s'):
            self.assertIn(label, labels)
        self.assertEqual(result['sketchibar.weather.current']['icon'], chr(0xece7))

    def test_snow_icon_and_missing_fields(self):
        payload = self.forecast()
        payload['current']['weather_code'] = 85
        result = self.data.weather(payload)
        self.assertEqual(result['sketchibar.weather.precip']['icon'], chr(0xea73))
        payload['hourly']['precipitation_probability'][1] = None
        self.assertEqual(self.data.weather(payload)['sketchibar.weather.precip']['label'], '—')
        self.assertTrue(all(v['label'] == '—' for v in self.data.weather({}).values()))

    def test_battery_hides_meaningless_times_and_restores_valid_time(self):
        for raw in ('no battery', '82%; charging; 0:00 remaining',
                    '82%; discharging; 0:00 remaining', '100%; charged; 0:00 remaining',
                    '82%; charging; (no estimate)', '82%; charging; 1:99 remaining'):
            with self.subTest(raw=raw):
                result = self.data.battery(raw)['sketchibar.battery.time']
                self.assertEqual(result['drawing'], 'off')
        valid = self.data.battery('82%; charging; 0:01 remaining')['sketchibar.battery.time']
        self.assertEqual(valid['drawing'], 'on')
        self.assertEqual(valid['label'], '↑ 0h 01m')

    def test_caffeine_remaining_time_matches_selected_pid(self):
        raw = (' pid 999(caffeinate): other\n Timeout will fire in 30 secs\n'
               ' pid 123(caffeinate): selected\n Timeout will fire in 86169 secs\n')
        state = self.data.caffeine('123', raw)['sketchibar.cafe.remaining']
        self.assertEqual(state['label'], '23h 56m')
        self.assertEqual(state['icon'], chr(0xf59a))
        self.assertEqual(self.data.caffeine('123', 'pid 123(caffeinate): no timeout')['sketchibar.cafe.remaining']['label'], '--')
        self.assertEqual(self.data.caffeine('', '')['sketchibar.cafe.remaining']['label'], 'Off')
        for seconds, expected in [(59, '<1m'), (60, '1m'), (0, '0m')]:
            self.assertEqual(self.data.caffeine('123', f'pid 123(caffeinate): x\nTimeout will fire in {seconds} secs')['sketchibar.cafe.remaining']['label'], expected)

    def test_cafe_off_hides_box_and_spacing_and_on_restores_them(self):
        for pid, drawing in [('', 'off'), ('123', 'on')]:
            values = self.data.caffeine(pid, 'pid 123(caffeinate): active\nTimeout will fire in 3600 secs')
            for name in ('sketchibar.cafe.remaining', 'sketchibar.cafe', 'sketchibar.gap.cafe'):
                self.assertIn(name, values)
                self.assertEqual(values[name]['drawing'], drawing)

    def test_cafe_event_collector_skips_slow_battery_and_bluetooth_queries(self):
        with patch.object(self.data.sys, 'argv', ['sketchibar-update', 'cafe']), \
             patch.object(self.data, 'system_lock'), \
             patch.object(self.data, 'caffeine_pid', return_value='123'), \
             patch.object(self.data, 'run', return_value='pid 123(caffeinate): active\nTimeout will fire in 120 secs') as run, \
             patch.object(self.data, 'render') as render:
            self.data.main()
        self.assertEqual([call.args for call in run.call_args_list], [('/usr/bin/pmset', '-g', 'assertions')])
        self.assertEqual(render.call_args.args[0]['sketchibar.cafe.remaining']['label'], '2m')

    def test_caffeine_selection_ignores_claude_resume_processes(self):
        with patch.object(self.data, 'run', side_effect=['111\n222', '10', 'claude --resume x', '20', 'fish']):
            self.assertEqual(self.data.caffeine_pid(), '222')

    def test_system_mode_collects_only_batteries_without_cafe_wifi_or_audio(self):
        with patch.object(self.data.sys, 'argv', ['sketchibar-update', 'system']), \
             patch.object(self.data, 'system_lock'), \
             patch.object(self.data, 'run', return_value='100%; charged; 0:00 remaining') as run, \
             patch.object(self.data, 'caffeine_pid') as caffeine_pid, \
             patch.object(self.data, 'render') as render:
            self.data.main()
        self.assertEqual([call.args for call in run.call_args_list],
                         [('/usr/bin/pmset', '-g', 'batt'),
                          ('/usr/sbin/system_profiler', '-timeout', '8', 'SPBluetoothDataType', '-json'),
                          ('/usr/sbin/ioreg', '-a', '-l', '-r', '-c', 'AppleDeviceManagementHIDEventService')])
        values = render.call_args.args[0]
        caffeine_pid.assert_not_called()
        self.assertEqual(set(values), {'sketchibar.battery.level', 'sketchibar.battery.time',
                                       'sketchibar.battery.keyboard', 'sketchibar.battery.trackpad'})

    def connected_devices(self):
        return {'SPBluetoothDataType': [{'device_connected': [
            {'Test Keyboard': {'device_minorType': 'Keyboard', 'device_batteryLevelMain': '100%'}},
            {'Test Trackpad': {'device_minorType': 'Magic Trackpad'}},
        ], 'device_not_connected': [
            {'Old Keyboard': {'device_minorType': 'Keyboard', 'device_batteryLevelMain': '80%'}}]}]}

    def test_connected_keyboard_and_trackpad_use_real_battery_and_tabler_icons(self):
        self.assertTrue(hasattr(self.data, 'device_batteries'), 'missing peripheral battery parser')
        values = self.data.device_batteries(self.connected_devices(), [
            {'Product': 'Test Trackpad', 'Transport': 'Bluetooth', 'BatteryPercent': 91},
            {'Product': 'Apple Internal Keyboard / Trackpad', 'BatteryPercent': 50},
        ])
        for kind, pct, glyph in [('keyboard', '100%', 0xebd6), ('trackpad', '91%', 0xed37)]:
            value = values['sketchibar.battery.' + kind]
            self.assertEqual(value['drawing'], 'on')
            self.assertEqual(value['label'], pct)
            self.assertEqual(value['icon'], chr(glyph))
            self.assertEqual(value['icon.color'], self.data.GREEN)

    def test_peripheral_disconnect_unknown_and_invalid_values_hide_instead_of_stale_data(self):
        self.assertTrue(hasattr(self.data, 'device_batteries'), 'missing peripheral battery parser')
        for bad in (None, True, -1, 101, 'unknown', '100% extra'):
            payload = self.connected_devices()
            payload['SPBluetoothDataType'][0]['device_connected'][0]['Test Keyboard']['device_batteryLevelMain'] = bad
            values = self.data.device_batteries(payload, [{'Product': 'Test Trackpad', 'Transport': 'Bluetooth', 'BatteryPercent': bad}])
            for value in values.values():
                self.assertEqual(value['drawing'], 'off')
                self.assertEqual(value['label'], '')
        for payload in ({}, {'SPBluetoothDataType': [{}]}, {'SPBluetoothDataType': None}):
            self.assertTrue(all(v['drawing'] == 'off' for v in self.data.device_batteries(payload, [
                {'Product': 'Test Trackpad', 'Transport': 'Bluetooth', 'BatteryPercent': 91}]).values()))

    def test_peripheral_low_battery_colors_and_hid_connection_gate(self):
        self.assertTrue(hasattr(self.data, 'device_batteries'), 'missing peripheral battery parser')
        for pct, color in [(0, self.data.RED), (20, self.data.RED), (21, '0xffc8945a'), (50, '0xffc8945a'), (51, self.data.GREEN)]:
            payload = self.connected_devices()
            payload['SPBluetoothDataType'][0]['device_connected'][0]['Test Keyboard']['device_batteryLevelMain'] = f'{pct}%'
            v = self.data.device_batteries(payload, [])['sketchibar.battery.keyboard']
            self.assertEqual(v['label'], f'{pct}%')
            self.assertEqual(v['icon.color'], color)
        v = self.data.device_batteries(self.connected_devices(), [
            {'Product': 'Different Trackpad', 'Transport': 'Bluetooth', 'BatteryPercent': 91},
        ])['sketchibar.battery.trackpad']
        self.assertEqual(v['drawing'], 'off')

    def test_peripheral_collection_tolerates_missing_sources(self):
        self.assertTrue(hasattr(self.data, 'collect_device_batteries'), 'missing peripheral collector')
        hid = plistlib.dumps([{'Product': 'Test Trackpad', 'Transport': 'Bluetooth', 'BatteryPercent': 91}]).decode()
        with patch.object(self.data, 'run', side_effect=[json.dumps(self.connected_devices()), hid]):
            values = self.data.collect_device_batteries()
        self.assertEqual(values['sketchibar.battery.trackpad']['label'], '91%')
        for replies in [('', ''), ('{}', 'bad plist'), (json.dumps(self.connected_devices()), '')]:
            with patch.object(self.data, 'run', side_effect=replies):
                values = self.data.collect_device_batteries()
            self.assertEqual(values['sketchibar.battery.trackpad']['drawing'], 'off')

    def test_overlapping_system_workers_publish_in_collection_order(self):
        self.assertTrue(hasattr(self.data, 'system_lock'), 'missing system collector serialization')
        older_read = threading.Event()
        release_older = threading.Event()
        newer_read = threading.Event()
        newer_started = threading.Event()
        published, failures = [], []
        def collect():
            if threading.current_thread().name == 'older':
                older_read.set()
                if not release_older.wait(3):
                    raise RuntimeError('older worker was not released')
                return {'sketchibar.battery.keyboard': {'drawing': 'on'}}
            newer_read.set()
            return {'sketchibar.battery.keyboard': {'drawing': 'off'}}
        def worker():
            if threading.current_thread().name == 'newer':
                newer_started.set()
            try:
                self.data.main()
            except Exception as exc:
                failures.append(exc)
        with tempfile.TemporaryDirectory() as tmp, \
             patch.object(self.data.Path, 'home', return_value=Path(tmp)), \
             patch.object(self.data.sys, 'argv', ['sketchibar-update', 'system']), \
             patch.object(self.data, 'run', return_value=''), \
             patch.object(self.data, 'caffeine_pid', return_value=''), \
             patch.object(self.data, 'collect_device_batteries', side_effect=collect), \
             patch.object(self.data, 'render', side_effect=lambda values, _: published.append(values['sketchibar.battery.keyboard']['drawing'])):
            older = threading.Thread(target=worker, name='older')
            newer = threading.Thread(target=worker, name='newer')
            older.start()
            try:
                self.assertTrue(older_read.wait(2))
                newer.start()
                self.assertTrue(newer_started.wait(2))
                self.assertFalse(newer_read.wait(.1), 'newer collection must wait for older publication')
            finally:
                release_older.set()
                older.join(4)
                if newer.ident is not None:
                    newer.join(4)
            self.assertFalse(older.is_alive() or newer.is_alive())
            self.assertEqual(failures, [])
            self.assertEqual(published, ['on', 'off'], 'newer disconnected snapshot must win')

if __name__ == '__main__':
    unittest.main()
