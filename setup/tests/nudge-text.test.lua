package.path='home/.hammerspoon/?.lua;'..package.path
local ok,T=pcall(require,'nudge.renderers.text');assert(ok,'Measured text fitting is not implemented')
local function measure(s) return utf8.len(s) end
local function eq(a,b) assert(table.concat(a,'|')==b,table.concat(a,'|')) end
eq(T.lines('가나다라마',3,2,measure),'가나다|라마')
eq(T.lines('가나다라마',3,1,measure),'가나…')
eq(T.lines('one\ntwo\nthree\nfour',8,3,measure),'one|two|three…')
eq(T.lines('',8,3,measure),'')
eq(T.lines('a\n\nb',8,3,measure),'a||b')
eq(T.lines('한글 😀\n다음',8,3,measure),'한글 😀|다음')
eq(T.lines('"<script>"',20,3,measure),'"<script>"')
eq(T.lines('abcd',0,3,measure),'')
assert(T.single('build\nalpha\tproject')=='build alpha project')
local calls=0
local lines=T.lines(string.rep('가',20000),20,3,function(s) calls=calls+1;return utf8.len(s) end)
assert(#lines==3 and utf8.len(lines[3])==20 and lines[3]:sub(-3)=='…' and calls<70)
print('PASS: nudge-text (UTF-8, bounded measurement, wrapping, ellipsis, empty content)')
