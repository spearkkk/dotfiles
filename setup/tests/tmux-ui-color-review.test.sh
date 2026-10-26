#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
artifact="$repo_root/share/themes/simhae/tmux-ui-color-review.html"

node - "$artifact" <<'NODE'
const fs = require('fs');
const vm = require('vm');

const artifact = process.argv[2];
if (!fs.existsSync(artifact)) {
  throw new Error(`missing artifact: ${artifact}`);
}

const html = fs.readFileSync(artifact, 'utf8');
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
if (!scriptMatch) throw new Error('missing inline script');

const context = { console };
context.globalThis = context;
vm.createContext(context);
vm.runInContext(scriptMatch[1], context);

const api = context.TmuxColorReview;
if (!api) throw new Error('missing TmuxColorReview API');

const expectedDefaults = {
  paneInactiveFg: '#C8AE6A', paneInactiveBg: '#0A1F2E',
  paneActiveFg: '#071420', paneActiveBg: '#C6D8E4',
  waitingFg: '#071420', waitingBg: '#C8AE6A',
  doneFg: '#071420', doneBg: '#68BE92',
  statusNormalFg: '#C6D8E4', statusNormalBg: '#24425C', statusNormalBorder: '#4A6E86', statusNormalInactive: '#4A6E86',
  statusPrefixFg: '#4A6E86', statusPrefixBg: '#0A1F2E', statusPrefixBorder: '#4A6E86', statusPrefixInactive: '#4A6E86',
  statusProdFg: '#071420', statusProdBg: '#C47A72', statusProdBorder: '#0A1F2E', statusProdInactive: '#071420',
  currentFg: '#071420', currentBg: '#C6D8E4'
};

if (JSON.stringify(api.defaults) !== JSON.stringify(expectedDefaults)) {
  throw new Error(`unexpected defaults: ${JSON.stringify(api.defaults)}`);
}

if (api.normalizeHex('#abc') !== '#AABBCC') throw new Error('short hex normalization failed');
if (api.normalizeHex('bad') !== null) throw new Error('invalid hex accepted');
if (api.contrastRatio('#000000', '#FFFFFF') !== 21) throw new Error('contrast ratio failed');
if (api.identifyPreset(api.defaults) !== 'current') throw new Error('current preset identification failed');
if (api.identifyPreset({ ...api.defaults, waitingBg: '#FFFFFF' }) !== 'custom') throw new Error('custom preset identification failed');
if (api.statusContextColors(api.defaults, 'prod').inactive !== '#071420') throw new Error('prod inactive preview color failed');

const customized = { ...api.defaults, waitingFg: '#112233', waitingBg: '#DDEEFF', statusProdBg: '#AABBCC' };
const snippet = api.buildSnippet(customized);
for (const expected of [
  "set -g @attention_waiting_fg '#112233'",
  "set -g @attention_waiting_bg '#DDEEFF'",
  "set -g window-style \"default\"",
  "set -g pane-border-style \"fg=#{?#{==:#{@attention_state},waiting},#{E:@attention_waiting_fg}",
  "set -g @status_normal_bg '#24425C'",
  "set -g @status_normal_fg '#C6D8E4'",
  "set -g @status_normal_border '#4A6E86'",
  "set -g @status_normal_inactive '#4A6E86'",
  "set -g @status_prefix_bg '#0A1F2E'",
  "set -g @status_prefix_fg '#4A6E86'",
  "set -g @status_prefix_border '#4A6E86'",
  "set -g @status_prefix_inactive '#4A6E86'",
  "set -g @status_prod_bg '#AABBCC'",
  "set -g @status_prod_fg '#071420'",
  "set -g @status_prod_border '#0A1F2E'",
  "set -g @status_prod_inactive '#071420'",
  "set -g status-style",
  "set -g @status_box_inactive",
  "#[underscore]#{window_index}#[nounderscore]",
  "#{?window_zoomed_flag",
  'status-box.sh "#{E:@status_box_bg}" "#{E:@status_box_fg}" "#{E:@status_box_border}"',
  '#AABBCC'
]) {
  if (!snippet.includes(expected)) throw new Error(`snippet missing: ${expected}`);
}

for (const option of ['@status_box_bg', '@status_box_fg', '@status_box_border', '@status_box_inactive']) {
  const line = snippet.split('\n').find(candidate => candidate.includes(option));
  if (!line || !line.includes('m/r:prod|dragon-kks|dragon-ssk|xpssk-02')) {
    throw new Error(`${option} does not preserve complete prod detection`);
  }
  if (!line.includes('#{E:@status_prefix_') || !line.includes('#{E:@status_prod_') || !line.includes('#{E:@status_normal_')) {
    throw new Error(`${option} does not resolve through semantic palette options`);
  }
}
if (snippet.includes('case $style_variant')) throw new Error('snippet still duplicates the renderer palette');

console.log('PASS: tmux-ui-color-review');
NODE
