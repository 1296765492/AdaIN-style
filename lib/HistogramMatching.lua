require 'nn'

--[[
Implements Histogram Matching to replace adaptive instance normalization (AdaIN) as described in the paper:

Arbitrary Style Transfer in Real-time with Adaptive Instance Normalization
Xun Huang, Serge Belongie
]]

local HistogramMatching, parent = torch.class('nn.HistogramMatching', 'nn.Module')

function HistogramMatching:__init(nOutput, disabled, eps)
    parent.__init(self)

    self.eps = eps or 1e-5

    self.nOutput = nOutput
    self.batchSize = -1
    self.disabled = disabled
end

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

function HistogramMatching:updateOutput(input) --{content, style}
    local content = input[1]
    local style = input[2]

    if self.disabled then
        self.output = content
        return self.output
    end        

    local N, Hc, Wc, Hs, Ws
    if content:nDimension() == 3 then
        assert(content:size(1) == self.nOutput)
        assert(style:size(1) == self.nOutput)
        N = 1
        Hc, Wc = content:size(2), content:size(3)
        Hs, Ws = style:size(2), style:size(3)
        content = content:view(1, self.nOutput, Hc, Wc)
        style = style:view(1, self.nOutput, Hs, Ws)
    elseif content:nDimension() == 4 then
        assert(content:size(1) == style:size(1))
        assert(content:size(2) == self.nOutput)
        assert(style:size(2) == self.nOutput)
        N = content:size(1)
        Hc, Wc = content:size(3), content:size(4)
        Hs, Ws = style:size(3), style:size(4)
    end
    
    --[[
    -- helper
    print(N, self.nOutput, Hc, Wc, Hs, Ws)
    for n = 1, N do 
      for c = 1, self.nOutput do
        for h = 1, Hc do
          for w = 1, Wc do
            print(content[n][c][h][w])
          end
        end
      end
    end
    for n = 1, N do 
      for c = 1, self.nOutput do
        for h = 1, Hs do
          for w = 1, Ws do
            print(style[n][c][h][w])
          end
        end
      end
    end
    ]]

    --[[
    -- compute target mean and standard deviation from the style input
    local styleView = style:view(N, self.nOutput, Hs*Ws)
    local targetStd = styleView:std(3, true):view(-1)
    local targetMean = styleView:mean(3):view(-1)

    -- construct the internal BN layer
    if N ~= self.batchSize or (self.bn and self:type() ~= self.bn:type()) then
        self.bn = nn.SpatialBatchNormalization(N * self.nOutput, self.eps)
        self.bn:type(self:type())
        self.batchSize = N
    end

    -- set affine params for the internal BN layer
    self.bn.weight:copy(targetStd)
    self.bn.bias:copy(targetMean)

    local contentView = content:view(1, N * self.nOutput, Hc, Wc)
    self.bn:training()
    self.output = self.bn:forward(contentView):viewAs(content)
    ]]
    self.output = content:clone()
    
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
        --[[
        print("content histo", n, c)
        for k, v in ipairs(cHistoMeta) do
          print(k, v, cHisto[v])
        end
        ]]
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
        --[[
        print("style histo", n, c)
        for k, v in ipairs(sHistoMeta) do
          print(k, v, sHisto[v])
        end
        ]]
        -- calculate cumulative distributive function (CDF) of content
        local cCDF = {}
        local sum = 0
        for k, v in ipairs(cHistoMeta) do
          cCDF[v] = sum + cHisto[v]
          sum = cCDF[v]
        end
        --[[
        print("content CDF", n, c)
        for k, v in ipairs(cHistoMeta) do
          print(k, v, cCDF[v])
        end
        ]]
        -- calculate cumulative distributive function (CDF) of style
        local sCDF = {}
        local sum = 0
        for k, v in ipairs(sHistoMeta) do
          sCDF[v] = sum + sHisto[v]
          sum = sCDF[v]
        end
        --[[
        print("style CDF", n, c)
        for k, v in ipairs(sHistoMeta) do
          print(k, v, sCDF[v])
        end
        ]]
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
        --[[
        print("match relation")
        for k, v in pairs(match) do
          print(k, v)
        end
        ]]
        -- construct output
        for h = 1, Hc do
          for w = 1, Wc do
            --[[
	    print("aux")
	    print(output[n][c][h][w])
	    print(round(output[n][c][h][w], numDP))
	    print(match[round(output[n][c][h][w], numDP)])
            ]]
            self.output[n][c][h][w] = match[round(self.output[n][c][h][w], numDP)]
          end
        end
        --[[
        print("output")
        printFeature(output)
        ]]
      end
    end
    
    return self.output
end

function HistogramMatching:updateGradInput(input, gradOutput)
    -- Not implemented
    self.gradInput = nil
    return self.gradInput
end

function HistogramMatching:clearState()
    self.output = self.output.new()
    self.gradInput[1] = self.gradInput[1].new()
    self.gradInput[2] = self.gradInput[2].new()
    -- if self.bn then self.bn:clearState() end
end
