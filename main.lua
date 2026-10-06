local Renderer = require("Services.Renderer")
local Object = require("Services.Object")
local Enum = require("Services.Enum")
local Gui = require("Services.Gui")

local Framerate, DeltaTime = 0, 0

function love.load()
    love.filesystem.setIdentity("Fragment")
    love.window.setTitle("Fragment")
    love.window.setMode(1280, 720, {
        resizable = true, vsync = 0,
        msaa = 8, highdpi = true,
        depth = 24, stencil = 8,
    })
    if love.filesystem.getInfo("Assets/Textures/Icon.png") then
        love.window.setIcon(love.image.newImageData("Assets/Textures/Icon.png"))
    end
    if love.filesystem.getInfo("Font.ttf") then
        love.graphics.setFont(love.graphics.newFont("Font.ttf", 14))
    end
    love.graphics.setDefaultFilter("nearest", "nearest")
end

function love.keypressed(Key)
    if Key == "escape" then love.event.quit()
    elseif Key == "f3" then love.event.quit("restart") end
end

local Camera = Object.New("Camera", Workspace)
Camera.Position = {0, 24, 0}
Camera.Rotation = {-90, 0, 0}
Camera.Fov = 50
Workspace.Camera = Camera

local Part = Object.New("Part", Workspace)
Part.Size = {4, 4, 4}
Part.Position = {0, 0, 0}
Part.Rotation = {0, 0, 0}
Part.RenderStyle = Enum.RenderStyle.Outline
Part.Mesh = Enum.Mesh.Icosphere(1)
Part.Color = {0.25, 1, 1}

function love.update(Delta)
    Framerate = Framerate + (1 / math.max(Delta, 1e-4) - Framerate) * math.min(1, Delta * 2)
    DeltaTime = DeltaTime + (Delta - DeltaTime) * math.min(1, Delta * 2)
end

function love.draw()
    Renderer.Draw()

    Gui:DrawText(string.format("Framerate : %06.1f/s", Framerate), { 8, 8 }, { 1, 1, 1, 1 })
    Gui:DrawText(string.format("Delta Time: %06.4fms", math.min(10 - 1e-4, DeltaTime * 1000)), { 8, 26 }, { 1, 1, 1, 1 })
    Gui:DrawText(string.format("%s      : %06.2fmb",
        math.floor(love.timer.getTime()) % 2 == 0 and "Ram " or "Vram",
        math.floor(love.timer.getTime()) % 2 == 0 and collectgarbage("count") / 1024 or love.graphics.getStats().texturememory / (1024 * 1024)),
        { 8, 44 }, { 1, 1, 1, 1 }
    )
end

function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg)) end
    if love.timer then love.timer.step() end
    local Pump, Poll, Handlers = love.event.pump, love.event.poll, love.handlers
    local Step, IsActive = love.timer.step, love.graphics.isActive
    local Origin, Clear, Present = love.graphics.origin, love.graphics.clear, love.graphics.present
    local Update = love.update or function() end
    local Draw = love.draw or function() end
    local Quit = love.quit
    return function()
        Pump()
        for Name, Ax, Bx, Cx, Dx, Ex, Fx in Poll() do
            if Name == "quit" then if not Quit or not Quit() then return Ax or 0 end
            else
                local H = Handlers[Name]
                if H then H(Ax, Bx, Cx, Dx, Ex, Fx) end
            end
        end
        Update(Step())
        if IsActive() then Origin(); Clear(); Draw(); Present() end
    end
end