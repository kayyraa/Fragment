local Shader = {}
Shader.__index = Shader

local Cache = {}
local Sources = {}

local function ReadFile(Path)
    if not love.filesystem.getInfo(Path) then
        return nil, "File not found: " .. tostring(Path)
    end
    local Content = love.filesystem.read(Path)
    if not Content then
        return nil, "Could not read: " .. tostring(Path)
    end
    return Content
end

local function ExtractStage(Source, StageName)
    local StartPos = Source:find("#ifdef%s+" .. StageName)
    if not StartPos then return nil end
    local LineEnd = Source:find("\n", StartPos)
    if not LineEnd then return nil end
    local EndPos = Source:find("#endif", LineEnd)
    if not EndPos then return nil end
    return Source:sub(LineEnd + 1, EndPos - 1)
end

local function TryCompile(Label, ...)
    local Args = {...}
    local Ok, Result = pcall(function()
        return love.graphics.newShader(unpack(Args))
    end)
    if Ok and Result then
        return true, Result
    end
    print("[Shader] Compile failed (" .. Label .. "):\n" .. tostring(Result))
    return false, Result
end

local function CompilePair(Label, VertexSource, FragmentSource)
    local Ok, Result = TryCompile(Label .. " (pixel,vertex)", FragmentSource, VertexSource)
    if Ok then return true, Result end
    Ok, Result = TryCompile(Label .. " (vertex,pixel)", VertexSource, FragmentSource)
    if Ok then return true, Result end
    return false, Result
end

function Shader.Load(SourceOrPath, PixelSource)
    local Key
    local Content

    if type(SourceOrPath) == "table" then
        local VertexSource = SourceOrPath.Vertex or SourceOrPath.vertex
        local FragmentSource = SourceOrPath.Pixel or SourceOrPath.Fragment or SourceOrPath.pixel or SourceOrPath.fragment
        Key = "table:" .. tostring(#(VertexSource or "")) .. ":" .. tostring(#(FragmentSource or "")) .. ":" .. tostring(VertexSource and VertexSource:sub(1, 24) or "")

        if Cache[Key] and Cache[Key]._VertexSource == VertexSource and Cache[Key]._FragmentSource == FragmentSource then
            return Cache[Key]
        end

        if not VertexSource or not FragmentSource then
            return nil
        end

        local Ok, Result = CompilePair("table", VertexSource, FragmentSource)
        if not Ok then return nil end

        local Instance = setmetatable({
            Handle = Result,
            Key = Key,
            Source = FragmentSource,
            _VertexSource = VertexSource,
            _FragmentSource = FragmentSource,
        }, Shader)
        Cache[Key] = Instance
        print("[Shader] Loaded: " .. Key)
        return Instance
    end

    if type(SourceOrPath) ~= "string" then
        error("[Shader] Invalid argument to Shader.Load")
    end

    local IsPath = SourceOrPath:match("%.glsl$") or SourceOrPath:match("%.vert$") or SourceOrPath:match("%.frag$")
    if IsPath then
        Key = SourceOrPath
        local Err
        Content, Err = ReadFile(SourceOrPath)
        if not Content then
            print("[Shader] " .. tostring(Err))
            return nil
        end
        Sources[Key] = Content
    else
        Key = "inline:" .. tostring(#SourceOrPath) .. ":" .. tostring(SourceOrPath:sub(1, 32))
        Content = SourceOrPath
    end

    if Cache[Key] then
        return Cache[Key]
    end

    local Ok, Result

    if type(PixelSource) == "string" then
        Ok, Result = CompilePair("explicit", SourceOrPath, PixelSource)
    else
        local HasVertex = Content:find("#ifdef%s+VERTEX")
        local HasPixel = Content:find("#ifdef%s+PIXEL")

        if HasVertex and HasPixel then
            Ok, Result = TryCompile("combined single string", Content)

            if not Ok then
                local VertexBody = ExtractStage(Content, "VERTEX")
                local PixelBody = ExtractStage(Content, "PIXEL")
                if VertexBody and PixelBody then
                    Ok, Result = CompilePair("split", VertexBody, PixelBody)
                end
            end
        else
            Ok, Result = TryCompile("pixel-only", Content)
        end
    end

    if not Ok then
        print("[Shader] FATAL: could not compile " .. tostring(Key))
        return nil
    end

    print("[Shader] Loaded: " .. tostring(Key))
    local Instance = setmetatable({
        Handle = Result,
        Key = Key,
        Source = Content,
    }, Shader)
    Cache[Key] = Instance
    return Instance
end

function Shader:Reload()
    if not self.Key then return false end
    Cache[self.Key] = nil
    local New = Shader.Load(self.Key)
    if New then
        self.Handle = New.Handle
        self.Source = New.Source
        return true
    end
    return false
end

function Shader:HasUniform(Name)
    if not self.Handle then return false end
    return self.Handle:hasUniform(Name)
end

local function FlatToNested(Flat)
    return {
        {Flat[1], Flat[5], Flat[9],  Flat[13]},
        {Flat[2], Flat[6], Flat[10], Flat[14]},
        {Flat[3], Flat[7], Flat[11], Flat[15]},
        {Flat[4], Flat[8], Flat[12], Flat[16]},
    }
end

local Warned = {}

function Shader:Send(NameOrTable, Value, ...)
    if not self.Handle then return end
    if type(NameOrTable) == "table" then
        for Key, Entry in pairs(NameOrTable) do
            self:Send(Key, Entry)
        end
        return
    end
    if not self.Handle:hasUniform(NameOrTable) then
        if not Warned[NameOrTable] then
            Warned[NameOrTable] = true
            print("[Shader] uniform not present (skipped): " .. NameOrTable)
        end
        return
    end

    if type(Value) == "table" and #Value == 16 and type(Value[1]) == "number" then
        Value = FlatToNested(Value)
    end

    local Ok, Err = pcall(self.Handle.send, self.Handle, NameOrTable, Value, ...)
    if not Ok then
        print("[Shader] send failed:", NameOrTable, Err)
    end
end

function Shader:Use()
    love.graphics.setShader(self.Handle)
end

function Shader.Clear()
    love.graphics.setShader()
end

function Shader:GetHandle()
    return self.Handle
end

function Shader.ClearCache()
    Cache = {}
end

return Shader