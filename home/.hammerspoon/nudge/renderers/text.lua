-- Fit plain UTF-8 text using an injected font measurement function. Never parse markup.
local M={}
local function clean(text)
  return (text or ''):gsub('\r\n','\n'):gsub('\r','\n'):gsub('\t',' '):gsub('[%z\1-\8\11\12\14-\31\127]','')
end
function M.single(text) return (clean(text):gsub('\n',' ')) end
function M.lines(text,width,limit,measure)
  if width<=0 then return {} end
  local chars,overflow={},false
  for _,code in utf8.codes(clean(text)) do
    if #chars==2048 then overflow=true;break end
    chars[#chars+1]=utf8.char(code)
  end
  local result,pos={},1
  local function fit(first,last,suffix)
    local lo,hi=0,last-first+1
    while lo<hi do
      local mid=math.floor((lo+hi+1)/2)
      if measure(table.concat(chars,'',first,first+mid-1)..suffix)<=width then lo=mid else hi=mid-1 end
    end
    return lo
  end
  while pos<=#chars and #result<limit do
    local last=pos
    while last<=#chars and chars[last]~='\n' do last=last+1 end
    local count=fit(pos,last-1,'')
    local next_pos=pos+count
    if next_pos==last and chars[last]=='\n' then next_pos=last+1 end
    local more=next_pos<=#chars or overflow
    local suffix=''
    if #result==limit-1 and more then
      suffix=measure('…')<=width and '…' or ''
      count=fit(pos,pos+count-1,suffix)
    end
    result[#result+1]=table.concat(chars,'',pos,pos+count-1)..suffix
    if count==0 and last>pos then break end -- even one glyph cannot fit
    pos=next_pos
  end
  return result
end
return M
