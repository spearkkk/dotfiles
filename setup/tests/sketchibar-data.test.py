#!/usr/bin/env python3
import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
import sys

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

    def test_caffeine_selection_ignores_claude_resume_processes(self):
        with patch.object(self.data, 'run', side_effect=['111\n222', '10', 'claude --resume x', '20', 'fish']):
            self.assertEqual(self.data.caffeine_pid(), '222')

    def test_system_mode_collects_battery_and_caffeine_without_wifi_or_audio(self):
        with patch.object(self.data.sys, 'argv', ['sketchibar-update', 'system']), \
             patch.object(self.data, 'run', return_value='100%; charged; 0:00 remaining') as run, \
             patch.object(self.data, 'caffeine_pid', return_value='123'), \
             patch.object(self.data, 'render') as render:
            self.data.main()
        self.assertEqual([call.args for call in run.call_args_list],
                         [('/usr/bin/pmset', '-g', 'batt'), ('/usr/bin/pmset', '-g', 'assertions')])
        values = render.call_args.args[0]
        self.assertEqual(set(values), {'sketchibar.battery.level', 'sketchibar.battery.time', 'sketchibar.cafe.remaining'})

if __name__ == '__main__':
    unittest.main()
