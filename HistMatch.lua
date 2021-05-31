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
local N = 1
local nOutput = 1
local Hc = 2
local Wc = 5
local Hs = 3
local Ws = 4
local content = featureRandomGenerator({}, N, nOutput, Hc, Wc)
print("content")
printFeature(content)
local style = featureRandomGenerator({}, N, nOutput, Hs, Ws)
print("style")
printFeature(style)

-- helper function: round
function round(num, numDecimalPlaces)
  local flag = 0
  if num < 0 then
    flag = 1
    num = -num
  end
  local mult = 10 ^ (numDecimalPlaces or 0)
  local output = math.floor(num * mult + 0.5) / mult
  if flag == 1 then
    output = -output
  end
  return output
end

-- prepare output table
local output = {} -- output can be cloned in adain
for n = 1, N do
  local maps = {}
  for c = 1, nOutput do
    local map = {}
    for h = 1, Hc do
      local line = {}
      for w = 1, Wc do
        line[w] = content[n][c][h][w]
      end
      map[h] = line
    end
    maps[c] = map
  end
  output[n] = maps
end

-- histogram matching
local numDP = 2
for n = 1, N do
  for c = 1, nOutput do
    -- for every channel or feature map
    -- generate histogram of content
    local cHisto = {}
    for h = 1, Hc do
      for w = 1, Wc do
        local num = round(content[n][c][h][w], numDP)
        if cHisto[num] == nil then
          cHisto[num] = 1
        else
          cHisto[num] = cHisto[num] + 1
        end
      end
    end
    for k, v in pairs(cHisto) do
      cHisto[k] = v / (Hc * Wc)
    end
    local cHistoMeta = {}
    for k, v in pairs(cHisto) do
      table.insert(cHistoMeta, k)
    end
    table.sort(cHistoMeta)
    print("content histo", n, c)
    for k, v in ipairs(cHistoMeta) do
      print(k, v, cHisto[v])
    end
    -- generate histogram of style
    local sHisto = {}
    for h = 1, Hs do
      for w = 1, Ws do
        local num = round(style[n][c][h][w], numDP)
        if sHisto[num] == nil then
          sHisto[num] = 1
        else
          sHisto[num] = sHisto[num] + 1
        end
      end
    end
    for k, v in pairs(sHisto) do
      sHisto[k] = v / (Hs * Ws)
    end
    local sHistoMeta = {}
    for k, v in pairs(sHisto) do
      table.insert(sHistoMeta, k)
    end
    table.sort(sHistoMeta)
    print("style histo", n, c)
    for k, v in ipairs(sHistoMeta) do
      print(k, v, sHisto[v])
    end
    -- calculate cumulative distributive function (CDF) of content
    local cCDF = {}
    local sum = 0
    for k, v in ipairs(cHistoMeta) do
      cCDF[v] = sum + cHisto[v]
      sum = cCDF[v]
    end
    print("content CDF", n, c)
    for k, v in ipairs(cHistoMeta) do
      print(k, v, cCDF[v])
    end
    -- calculate cumulative distributive function (CDF) of style
    local sCDF = {}
    local sum = 0
    for k, v in ipairs(sHistoMeta) do
      sCDF[v] = sum + sHisto[v]
      sum = sCDF[v]
    end
    print("style CDF", n, c)
    for k, v in ipairs(sHistoMeta) do
      print(k, v, sCDF[v])
    end
    -- match histogram
    local match = {}
    local index = 1
    for k1, v1 in ipairs(cHistoMeta) do
      if cCDF[v1] < sCDF[sHistoMeta[index]] then
        match[v1] = sHistoMeta[index]
      else
        if cCDF[v1] < sCDF[sHistoMeta[index + 1]] then
          match[v1] = sHistoMeta[index]
	else
          for i = index + 1, #sHistoMeta do
	    if i == #sHistoMeta then
	      index = i
	      break
            end
	    if cCDF[v1] >= sCDF[sHistoMeta[i]] and cCDF[v1] < sCDF[sHistoMeta[i + 1]] then
	      index = i
	      break
	    end
	  end
          match[v1] = sHistoMeta[index]
	end
      end
    end
    print("match relation")
    for k, v in pairs(match) do
      print(k, v)
    end
    -- construct output
    for h = 1, Hc do
      for w = 1, Wc do
	print("aux")
	print(output[n][c][h][w])
	print(round(output[n][c][h][w], numDP))
	print(match[round(output[n][c][h][w], numDP)])
        output[n][c][h][w] = match[round(output[n][c][h][w], numDP)]
      end
    end
    print("output")
    printFeature(output)
  end
end
