local Gui = {}

function Gui:DrawText(Text, Position, Size, Options)
    Options = Options or {}
    Position = Position or { 0, 0 }
    Text = tostring(Text or "")
    local Color = Options.Color or { 1, 1, 1, 1 }
    local Scale = 1
    if type(Size) == "table" then
        Color = Size
    elseif type(Size) == "number" then
        Scale = Size
    end
    local X = Position[1] or Position.X or 0
    local Y = Position[2] or Position.Y or 0
    love.graphics.setColor(Color[1] or 1, Color[2] or 1, Color[3] or 1, Color[4] or 1)
    if Scale ~= 1 then
        love.graphics.push()
        love.graphics.translate(X, Y)
        love.graphics.scale(Scale)
        love.graphics.print(Text, 0, 0)
        love.graphics.pop()
    else
        love.graphics.print(Text, X, Y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Gui:Measure(Text, Scale)
    local F = love.graphics.getFont()
    if not F then return 0, 0 end
    return F:getWidth(Text) * (Scale or 1), F:getHeight() * (Scale or 1)
end

return Gui