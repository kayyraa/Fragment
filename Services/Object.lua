local Object = {}
Object.__index = Object

local Signal = {}
Signal.__index = Signal

local function CloneTable(Source)
    local Copy = {}
    for Key, Value in pairs(Source) do
        Copy[Key] = Value
    end
    return Copy
end

local function ClearTable(Target)
    for Key in pairs(Target) do
        Target[Key] = nil
    end
end

function Signal.New()
    return setmetatable({
        Connections = {},
        Destroyed = false
    }, Signal)
end

function Signal:Connect(Callback)
    assert(type(Callback) == "function", "Callback must be a function")
    assert(not self.Destroyed, "Signal has been destroyed")
    local Connection = {
        Connected = true,
        Callback = Callback,
        Signal = self
    }
    function Connection:Disconnect()
        if not self.Connected then
            return
        end
        self.Connected = false
        self.Callback = nil
    end
    table.insert(self.Connections, Connection)
    return Connection
end

function Signal:Once(Callback)
    local Connection
    Connection = self:Connect(function(...)
        Connection:Disconnect()
        Callback(...)
    end)
    return Connection
end

function Signal:Fire(...)
    if self.Destroyed then
        return
    end
    local Connections = CloneTable(self.Connections)
    for _, Connection in ipairs(Connections) do
        if Connection.Connected then
            Connection.Callback(...)
        end
    end
    for Index = #self.Connections, 1, -1 do
        if not self.Connections[Index].Connected then
            table.remove(self.Connections, Index)
        end
    end
end

function Signal:Destroy()
    self.Destroyed = true
    table.clear(self.Connections)
end

local function GetClassName(Class)
    if type(Class) == "table" then
        return Class.ClassName or Class.Name or "Object"
    end
    return type(Class) == "string" and Class or "Object"
end

local function GetClassDefinition(Class)
    if type(Class) == "table" then
        return Class
    end
    return nil
end

local function GetMethod(Object, Name)
    local ClassDefinition = rawget(Object, "ClassDefinition")
    while ClassDefinition do
        local Value = rawget(ClassDefinition, Name)
        if Value ~= nil then
            return Value
        end
        local Metatable = getmetatable(ClassDefinition)
        ClassDefinition = Metatable and Metatable.__index
        if type(ClassDefinition) ~= "table" then
            break
        end
    end
    return rawget(Object, Name) or Object[Name]
end

local function CreateSignal(Object, Name)
    Object[Name] = Signal.New()
end

local function GetAncestors(Object)
    local Ancestors = {}
    local Parent = Object.Parent
    while Parent do
        table.insert(Ancestors, Parent)
        Parent = Parent.Parent
    end
    return Ancestors
end

local function IsDescendantOf(Object, Target)
    local Parent = Object.Parent
    while Parent do
        if Parent == Target then
            return true
        end
        Parent = Parent.Parent
    end
    return false
end

local function UpdateAncestry(Object, PreviousParent, CurrentParent)
    Object.AncestryChanged:Fire(Object, CurrentParent)
    for _, Descendant in ipairs(Object:GetDescendants()) do
        Descendant.AncestryChanged:Fire(Descendant, Descendant.Parent)
    end
    if PreviousParent then
        PreviousParent.DescendantRemoved:Fire(Object)
        for _, Descendant in ipairs(Object:GetDescendants()) do
            PreviousParent.DescendantRemoved:Fire(Descendant)
        end
    end
    if CurrentParent then
        CurrentParent.DescendantAdded:Fire(Object)
        for _, Descendant in ipairs(Object:GetDescendants()) do
            CurrentParent.DescendantAdded:Fire(Descendant)
        end
    end
end

function Object.New(Class, Parent)
    local ClassDefinition = GetClassDefinition(Class)
    local ClassName = GetClassName(Class)
    local Instance = setmetatable({
        Class = ClassName,
        ClassName = ClassName,
        ClassDefinition = ClassDefinition,
        Name = ClassName,
        Children = {},
        _Parent = nil,
        _Destroyed = false
    }, {
        __index = function(Self, Key)
            if Key == "Parent" then
                return rawget(Self, "_Parent")
            end
            local Definition = rawget(Self, "ClassDefinition")
            while Definition do
                local Value = rawget(Definition, Key)
                if Value ~= nil then
                    return Value
                end
                local Metatable = getmetatable(Definition)
                Definition = Metatable and Metatable.__index
                if type(Definition) ~= "table" then
                    break
                end
            end
            return Object[Key]
        end,
        __newindex = function(Self, Key, Value)
            if Key == "Parent" then
                Self:SetParent(Value)
                return
            end
            rawset(Self, Key, Value)
        end
    })
    CreateSignal(Instance, "ChildAdded")
    CreateSignal(Instance, "ChildRemoved")
    CreateSignal(Instance, "DescendantAdded")
    CreateSignal(Instance, "DescendantRemoved")
    CreateSignal(Instance, "AncestryChanged")
    CreateSignal(Instance, "Destroying")
    if Parent == nil and ClassName ~= "Workspace" then
        Parent = _G.Workspace
    end
    if Parent then
        Instance:SetParent(Parent)
    end
    return Instance
end

function Object:SetParent(Parent)
    assert(not self._Destroyed, "Cannot reparent a destroyed object")
    if Parent ~= nil then
        assert(type(Parent) == "table", "Parent must be an object or nil")
        assert(Parent ~= self, "An object cannot parent itself")
        assert(not Parent._Destroyed, "Cannot parent to a destroyed object")
        assert(not IsDescendantOf(Parent, self), "Cannot create a hierarchy cycle")
    end
    local PreviousParent = self._Parent
    if PreviousParent == Parent then
        return
    end
    local PreviousAncestors = GetAncestors(self)
    if PreviousParent then
        for Index, Child in ipairs(PreviousParent.Children) do
            if Child == self then
                table.remove(PreviousParent.Children, Index)
                break
            end
        end
        PreviousParent.ChildRemoved:Fire(self)
    end
    rawset(self, "_Parent", Parent)
    if Parent then
        table.insert(Parent.Children, self)
        Parent.ChildAdded:Fire(self)
    end
    local CurrentAncestors = GetAncestors(self)
    self.AncestryChanged:Fire(self, Parent)
    for _, Descendant in ipairs(self:GetDescendants()) do
        Descendant.AncestryChanged:Fire(Descendant, Descendant.Parent)
    end
    for _, Ancestor in ipairs(PreviousAncestors) do
        local StillAncestor = false
        for _, CurrentAncestor in ipairs(CurrentAncestors) do
            if CurrentAncestor == Ancestor then
                StillAncestor = true
                break
            end
        end
        if not StillAncestor then
            Ancestor.DescendantRemoved:Fire(self)
            for _, Descendant in ipairs(self:GetDescendants()) do
                Ancestor.DescendantRemoved:Fire(Descendant)
            end
        end
    end
    for _, Ancestor in ipairs(CurrentAncestors) do
        local WasAncestor = false
        for _, PreviousAncestor in ipairs(PreviousAncestors) do
            if PreviousAncestor == Ancestor then
                WasAncestor = true
                break
            end
        end
        if not WasAncestor then
            Ancestor.DescendantAdded:Fire(self)
            for _, Descendant in ipairs(self:GetDescendants()) do
                Ancestor.DescendantAdded:Fire(Descendant)
            end
        end
    end
end

function Object:GetChildren()
    return table.clone(self.Children)
end

function Object:GetDescendants()
    local Descendants = {}
    local Stack = {}
    for Index = #self.Children, 1, -1 do
        Stack[#Stack + 1] = self.Children[Index]
    end
    while #Stack > 0 do
        local Instance = table.remove(Stack)
        Descendants[#Descendants + 1] = Instance
        for Index = #Instance.Children, 1, -1 do
            Stack[#Stack + 1] = Instance.Children[Index]
        end
    end
    return Descendants
end

function Object:FindFirstChild(Name, Recursive)
    for _, Child in ipairs(self.Children) do
        if Child.Name == Name then
            return Child
        end
    end
    if Recursive then
        for _, Descendant in ipairs(self:GetDescendants()) do
            if Descendant.Name == Name then
                return Descendant
            end
        end
    end
    return nil
end

function Object:FindFirstChildOfClass(ClassName)
    for _, Child in ipairs(self.Children) do
        if Child.ClassName == ClassName then
            return Child
        end
    end
    return nil
end

function Object:IsA(ClassName)
    if self.ClassName == ClassName then
        return true
    end
    local Definition = self.ClassDefinition
    while Definition do
        if Definition.ClassName == ClassName then
            return true
        end
        local Metatable = getmetatable(Definition)
        Definition = Metatable and Metatable.__index
        if type(Definition) ~= "table" then
            break
        end
    end
    return ClassName == "Object"
end

function Object:GetFullName()
    local Names = { self.Name }
    local Parent = self.Parent
    while Parent do
        table.insert(Names, 1, Parent.Name)
        Parent = Parent.Parent
    end
    return table.concat(Names, ".")
end

function Object:Destroy()
    if self._Destroyed then
        return
    end
    self.Destroying:Fire()
    while #self.Children > 0 do
        self.Children[#self.Children]:Destroy()
    end
    self:SetParent(nil)
    self._Destroyed = true
    for _, Name in ipairs({
        "ChildAdded",
        "ChildRemoved",
        "DescendantAdded",
        "DescendantRemoved",
        "AncestryChanged",
        "Destroying"
    }) do
        self[Name]:Destroy()
    end
end

_G.Workspace = Object.New("Workspace")
return Object