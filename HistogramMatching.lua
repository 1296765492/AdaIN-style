-- helper function: generate content and style features
function featureRandomGenerator(feature, number, channel, height, width)
  for n = 1, number do
    local maps = {}
    for c = 1, channel do
      local map = {}
      for h = 1, height do
        local line = {}
        for w = 1, width do
          line[w] = math.random()
        end
        map[h] = line
      end
      maps[c] = map
    end
    feature[n] = maps
  end
  return feature
end
-- helper function: print features
function printFeature(feature)
  -- 4 dimensions only
  for k1, v1 in ipairs(feature) do
    print(k1)
    for k2, v2 in ipairs(feature[k1]) do
      print(k2)
      for k3, v3 in ipairs(feature[k1][k2]) do
        print(k3)
        for k4, v4 in ipairs(feature[k1][k2][k3]) do
          print(k4, v4)
        end
      end
    end
  end
end
-- generate and print content and style features
local content = featureRandomGenerator({}, 2, 2, 2, 2)
printFeature(content)
local style = featureRandomGenerator({}, 2, 2, 2, 2)
printFeature(style)
-- helper function: round
function round(num, numDecimalPlaces)
  local flag = 0
  if num < 0 then
    flag = 1
    num = -num
  end
  local mult = 10^(numDecimalPlaces or 0)
  local output = math.floor(num * mult + 0.5) / mult
  if flag == 1 then
    output = -output
  end
  return output
end
-- histogram matching
local numDP = 1
local multi = 10^(numDP or 0)
for n = 1, #content do
  for c = 1, #content[n] do
    -- for every channel or feature map
    -- generate histogram
    local cHisto = {}
    for h = 1, #content[n][c] do
      for w = 1, #content[n][c][h] do
        local num = round(content[n][c][h][w], numDP) * multi
        if cHisto[num] == nil then
          cHisto[num] = 1
        else
          cHisto[num] = cHisto[num] + 1
        end
      end
    end
    
    for k, v in pairs(cHisto) do
      print(k, v)
    end
    -- calculate cumulative distributive function (CDF)
    -- match histogram
  end
end