local Matrix = require("Services.Matrix")
local Enum = require("Services.Enum")

local Renderer = {}

Renderer.Light = {
    Direction = {0.4, 0.8, 0.3},
    Color = {1.0, 0.95, 0.9},
    Ambient = {0.25, 0.27, 0.32},
    Intensity = 0.9,
}

local ShaderHandle = nil
local ShaderFailed = false
local SurfaceMeshes = setmetatable({}, {__mode = "k"})
local EdgeMeshes = setmetatable({}, {__mode = "k"})

-- Both mesh kinds share this format; VertexAux is the normal (surface) or the other endpoint (edge)
local MeshFormat = {
    {"VertexPosition", "float", 3},
    {"VertexTexCoord", "float", 2},
    {"VertexAux", "float", 3},
}

local function Clamp01(X) return math.max(0, math.min(1, X)) end

local function EnsureShader()
    if ShaderHandle then return ShaderHandle end
    if ShaderFailed then return nil end

    local Source = love.filesystem.read("Assets/Shaders/Vertex.glsl")
    if not Source then
        print("[Renderer] Could not read Assets/Shaders/Vertex.glsl")
        ShaderFailed = true
        return nil
    end

    -- Keep shader style ids in sync with Enum.RenderStyle
    local Defines = ""
    for Name, Value in pairs(Enum.RenderStyle) do
        Defines = Defines .. string.format("#define STYLE_%s %d\n", Name:upper(), Value)
    end

    local Ok, Result = pcall(love.graphics.newShader, Defines .. Source)
    if not Ok then
        print("[Renderer] Shader failed: " .. tostring(Result))
        ShaderFailed = true
        return nil
    end
    ShaderHandle = Result
    return ShaderHandle
end

local function Send(Name, Value)
    if ShaderHandle:hasUniform(Name) then ShaderHandle:send(Name, Value) end
end

local function FlatToNested(Flat)
    return {
        {Flat[1], Flat[5], Flat[9],  Flat[13]},
        {Flat[2], Flat[6], Flat[10], Flat[14]},
        {Flat[3], Flat[7], Flat[11], Flat[15]},
        {Flat[4], Flat[8], Flat[12], Flat[16]},
    }
end

-- Inverse-transpose of the model's upper 3x3 (correct under non-uniform scale)
local function NormalMatrix(M)
    local Ax, Ay, Az = M[1], M[2], M[3]
    local Bx, By, Bz = M[5], M[6], M[7]
    local Cx, Cy, Cz = M[9], M[10], M[11]
    local N0 = {By*Cz - Bz*Cy, Bz*Cx - Bx*Cz, Bx*Cy - By*Cx}
    local N1 = {Cy*Az - Cz*Ay, Cz*Ax - Cx*Az, Cx*Ay - Cy*Ax}
    local N2 = {Ay*Bz - Az*By, Az*Bx - Ax*Bz, Ax*By - Ay*Bx}
    local Det = Ax*N0[1] + Ay*N0[2] + Az*N0[3]
    if math.abs(Det) < 1e-12 then Det = 1 end
    return {
        {N0[1]/Det, N1[1]/Det, N2[1]/Det},
        {N0[2]/Det, N1[2]/Det, N2[2]/Det},
        {N0[3]/Det, N1[3]/Det, N2[3]/Det},
    }
end

local function FaceNormal(Face)
    local Nx, Ny, Nz = 0, 0, 0
    local Count = #Face
    for I = 1, Count do
        local A, B = Face[I], Face[I % Count + 1]
        Nx = Nx + (A[2] - B[2]) * (A[3] + B[3])
        Ny = Ny + (A[3] - B[3]) * (A[1] + B[1])
        Nz = Nz + (A[1] - B[1]) * (A[2] + B[2])
    end
    local Length = math.sqrt(Nx*Nx + Ny*Ny + Nz*Nz)
    if Length < 1e-9 then return 0, 1, 0 end
    return Nx/Length, Ny/Length, Nz/Length
end

local function BuildSurfaceMesh(Faces)
    local Verts = {}
    for _, Face in ipairs(Faces) do
        local Count = #Face
        if Count >= 3 then
            local Nx, Ny, Nz = FaceNormal(Face)
            local function Push(P, U, V)
                Verts[#Verts + 1] = {P[1], P[2], P[3], U, V, Nx, Ny, Nz}
            end
            for I = 2, Count - 1 do
                Push(Face[1], 0, 0)
                Push(Face[I], 1, 0)
                Push(Face[I + 1], 1, 1)
            end
        end
    end
    if #Verts == 0 then return nil end
    return love.graphics.newMesh(MeshFormat, Verts, "triangles", "static")
end

local function BuildEdgeMesh(Faces)
    local Verts = {}
    local function V(P, Other, End, Side)
        return {P[1], P[2], P[3], End, Side, Other[1], Other[2], Other[3]}
    end
    for _, Face in ipairs(Faces) do
        local Count = #Face
        if Count >= 2 then
            for I = 1, Count do
                local A, B = Face[I], Face[I % Count + 1]
                local A0, A1 = V(A, B, 0, -1), V(A, B, 0, 1)
                local B0, B1 = V(B, A, 1, -1), V(B, A, 1, 1)
                Verts[#Verts + 1] = A0; Verts[#Verts + 1] = A1; Verts[#Verts + 1] = B1
                Verts[#Verts + 1] = A0; Verts[#Verts + 1] = B1; Verts[#Verts + 1] = B0
            end
        end
    end
    if #Verts == 0 then return nil end
    return love.graphics.newMesh(MeshFormat, Verts, "triangles", "static")
end

local function GetMesh(Cache, Builder, Part)
    local Def = Part.Mesh
    if not Def or not Def.Faces then return nil end
    local Mesh = Cache[Def]
    if Mesh == nil then
        Mesh = Builder(Def.Faces) or false
        Cache[Def] = Mesh
    end
    return Mesh or nil
end

local function PartModelMatrix(Part)
    local S = Part.Size or {1, 1, 1}
    local P = Part.Position or {0, 0, 0}
    local R = Part.Rotation or {0, 0, 0}
    return Matrix.FromTRSdegrees(P[1], P[2], P[3], R[1], R[2], R[3], S[1], S[2], S[3])
end

local function BuildFrame()
    local Cam = Workspace and Workspace.Camera
    if not Cam then return nil end

    local Width, Height = love.graphics.getWidth(), love.graphics.getHeight()
    local Aspect = Width / math.max(1, Height)
    local Proj = Matrix.Perspective(math.rad(Cam.Fov or 70), Aspect, Cam.Near or 0.1, Cam.Far or 1000)

    local Eye = Cam.Position or {0, 0, 5}
    local Target = Cam.Target
    if not Target then
        local R = Cam.Rotation or {0, 0, 0}
        local Pitch, Yaw = math.rad(R[1] or 0), math.rad(R[2] or 0)
        local Cp, Sp = math.cos(Pitch), math.sin(Pitch)
        local Cy, Sy = math.cos(Yaw), math.sin(Yaw)
        Target = {Eye[1] + Sy * Cp, Eye[2] + Sp, Eye[3] + (-Cy * Cp)}
    end
    local Up = Cam.Up
    if not Up then
        local Fx, Fy, Fz = Target[1] - Eye[1], Target[2] - Eye[2], Target[3] - Eye[3]
        if math.abs(Fy) > 0.99 * math.sqrt(Fx*Fx + Fy*Fy + Fz*Fz) then
            Up = {0, 0, -1}
        else
            Up = {0, 1, 0}
        end
    end

    return {
        View = FlatToNested(Matrix.LookAt(Eye, Target, Up)),
        Proj = FlatToNested(Proj),
        Eye = Eye,
        Width = Width,
        Height = Height,
        DepthRange = Cam.DepthRange or 64,
        Canvas = love.graphics.getCanvas() ~= nil,
    }
end

local function SendFrame(Frame)
    local Light = Renderer.Light
    Send("viewMatrix", Frame.View)
    Send("projectionMatrix", Frame.Proj)
    Send("isCanvasEnabled", Frame.Canvas)
    Send("viewport", {Frame.Width, Frame.Height})
    Send("viewPos", Frame.Eye)
    Send("depthRange", Frame.DepthRange)
    Send("depthBias", 1e-5)
    Send("lightDir", Light.Direction)
    Send("lightColor", Light.Color)
    Send("ambientColor", Light.Ambient)
    Send("lightIntensity", Light.Intensity)
end

local function DrawPart(Part)
    local Style = Part.RenderStyle or Enum.RenderStyle.Shaded
    local Transparency = Clamp01(Part.Transparency or 0)
    local Color = Part.Color or {1, 1, 1}
    local Model = PartModelMatrix(Part)

    Send("modelMatrix", FlatToNested(Model))
    Send("normalMatrix", NormalMatrix(Model))
    Send("renderStyle", Style)
    Send("transparency", Transparency)
    Send("fillColor", Part.FillColor or {0, 0, 0})
    Send("lineWidth", Part.LineWidth or 1.5)

    if Style ~= Enum.RenderStyle.Wireframe then
        local Mesh = GetMesh(SurfaceMeshes, BuildSurfaceMesh, Part)
        if Mesh then
            Send("edgePass", false)
            love.graphics.setColor(Color[1], Color[2], Color[3], 1)
            love.graphics.setDepthMode("lequal", Transparency == 0)
            love.graphics.draw(Mesh)
        end
    end

    if Style == Enum.RenderStyle.Wireframe or Style == Enum.RenderStyle.Outline then
        local Mesh = GetMesh(EdgeMeshes, BuildEdgeMesh, Part)
        if Mesh then
            Send("edgePass", true)
            Send("edgeColor", {Color[1], Color[2], Color[3], 1 - Transparency})
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setDepthMode("lequal", false)
            love.graphics.draw(Mesh)
        end
    end
end

function Renderer.Draw()
    local Frame = BuildFrame()
    if not Frame then return end
    if not EnsureShader() then return end

    local Opaque, Late = {}, {}
    local Eye = Frame.Eye

    local function Visit(Node)
        if Node.ClassName == "Part" and Node.Mesh then
            local Style = Node.RenderStyle or Enum.RenderStyle.Shaded
            if (Node.Transparency or 0) > 0 or Style == Enum.RenderStyle.Wireframe then
                local P = Node.Position or {0, 0, 0}
                local Dx, Dy, Dz = P[1] - Eye[1], P[2] - Eye[2], P[3] - Eye[3]
                Late[#Late + 1] = {Part = Node, Distance = Dx*Dx + Dy*Dy + Dz*Dz}
            else
                Opaque[#Opaque + 1] = Node
            end
        end
        if Node.Children then
            for _, Child in ipairs(Node.Children) do Visit(Child) end
        end
    end
    Visit(Workspace)

    love.graphics.setShader(ShaderHandle)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    SendFrame(Frame)

    for _, Part in ipairs(Opaque) do
        DrawPart(Part)
    end

    -- Transparent / wireframe parts: back to front, no depth writes
    table.sort(Late, function(A, B) return A.Distance > B.Distance end)
    for _, Item in ipairs(Late) do
        DrawPart(Item.Part)
    end

    love.graphics.setShader()
    love.graphics.setDepthMode()
    love.graphics.setColor(1, 1, 1, 1)
end

return Renderer