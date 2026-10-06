local Enum = {}

Enum.RenderStyle = {
    Wireframe = 1,
    Outline = 7,
    Normals = 5,
    Shaded = 2,
    Depth = 6,
}

Enum.Mesh = {}

Enum.Mesh.Square = {
    Faces = {
        { {-0.5, 0,-0.5}, {-0.5, 0, 0.5}, { 0.5, 0, 0.5}, { 0.5, 0,-0.5} },
    }
}

Enum.Mesh.Circle = function(Subdivisions)
    Subdivisions = Subdivisions or 3

    local Radius = 0.5
    local Segments = 4 * 2 ^ Subdivisions
    local Face = {}

    for i = 0, Segments - 1 do
        local A = (i / Segments) * math.pi * 2
        Face[#Face + 1] = { math.sin(A) * Radius, 0, math.cos(A) * Radius }
    end

    return { Faces = { Face } }
end

Enum.Mesh.Cube = {
    Faces = {
        { {-0.5,-0.5,-0.5}, {-0.5, 0.5,-0.5}, { 0.5, 0.5,-0.5}, { 0.5,-0.5,-0.5} },
        { {-0.5,-0.5, 0.5}, { 0.5,-0.5, 0.5}, { 0.5, 0.5, 0.5}, {-0.5, 0.5, 0.5} },
        { {-0.5,-0.5,-0.5}, { 0.5,-0.5,-0.5}, { 0.5,-0.5, 0.5}, {-0.5,-0.5, 0.5} },
        { {-0.5, 0.5,-0.5}, {-0.5, 0.5, 0.5}, { 0.5, 0.5, 0.5}, { 0.5, 0.5,-0.5} },
        { {-0.5,-0.5,-0.5}, {-0.5,-0.5, 0.5}, {-0.5, 0.5, 0.5}, {-0.5, 0.5,-0.5} },
        { { 0.5,-0.5,-0.5}, { 0.5, 0.5,-0.5}, { 0.5, 0.5, 0.5}, { 0.5,-0.5, 0.5} },
    }
}

Enum.Mesh.Pyramid = {
    Faces = {
        { {-0.5,-0.5,-0.5}, {-0.5,-0.5, 0.5}, { 0.5,-0.5, 0.5}, { 0.5,-0.5,-0.5} },
        { {-0.5,-0.5,-0.5}, { 0.5,-0.5,-0.5}, {0, 0.5, 0} },
        { { 0.5,-0.5,-0.5}, { 0.5,-0.5, 0.5}, {0, 0.5, 0} },
        { { 0.5,-0.5, 0.5}, {-0.5,-0.5, 0.5}, {0, 0.5, 0} },
        { {-0.5,-0.5, 0.5}, {-0.5,-0.5,-0.5}, {0, 0.5, 0} },
    }
}

Enum.Mesh.Wedge = {
    Faces = {
        { {-0.5,-0.5,-0.5}, {-0.5,-0.5, 0.5}, { 0.5,-0.5, 0.5}, { 0.5,-0.5,-0.5} },
        { {-0.5,-0.5,-0.5}, {-0.5, 0.5,-0.5}, {-0.5, 0.5, 0.5}, {-0.5,-0.5, 0.5} },
        { { 0.5,-0.5,-0.5}, { 0.5,-0.5, 0.5}, {-0.5, 0.5, 0.5}, {-0.5, 0.5,-0.5} },
        { {-0.5,-0.5,-0.5}, { 0.5,-0.5,-0.5}, {-0.5, 0.5,-0.5} },
        { {-0.5,-0.5, 0.5}, {-0.5, 0.5, 0.5}, { 0.5,-0.5, 0.5} },
    }
}

Enum.Mesh.Icosphere = function(Detail)
    Detail = math.max(1, math.floor(Detail or 1))
    local GoldenRatio = (1.0 + math.sqrt(5.0)) / 2.0
    local Base = {
        {-1, GoldenRatio, 0}, {1, GoldenRatio, 0}, {-1, -GoldenRatio, 0}, {1, -GoldenRatio, 0},
        {0, -1, GoldenRatio}, {0, 1, GoldenRatio}, {0, -1, -GoldenRatio}, {0, 1, -GoldenRatio},
        {GoldenRatio, 0, -1}, {GoldenRatio, 0, 1}, {-GoldenRatio, 0, -1}, {-GoldenRatio, 0, 1},
    }
    local BaseFaces = {
        {1, 12, 6}, {1, 6, 2}, {1, 2, 8}, {1, 8, 11}, {1, 11, 12},
        {2, 6, 10}, {6, 12, 5}, {12, 11, 3}, {11, 8, 7}, {8, 2, 9},
        {4, 10, 5}, {4, 5, 3}, {4, 3, 7}, {4, 7, 9}, {4, 9, 10},
        {5, 10, 6}, {3, 5, 12}, {7, 3, 11}, {9, 7, 8}, {10, 9, 2},
    }

    local function Normalize(X, Y, Z)
        local Length = math.sqrt(X*X + Y*Y + Z*Z)
        return {X / Length, Y / Length, Z / Length}
    end

    -- Shared points so neighboring triangles reuse the same vertex tables
    local Cache = {}
    local function Point(Ia, Ib, Ic, I, J, K)
        -- I, J, K are barycentric weights (sum = Detail)
        local Key = Ia .. ":" .. Ib .. ":" .. Ic .. ":" .. I .. ":" .. J .. ":" .. K
        return Key
    end

    local Out = {}
    for _, Tri in ipairs(BaseFaces) do
        local A, B, C = Base[Tri[1]], Base[Tri[2]], Base[Tri[3]]

        local function Get(I, J) -- point at weights (Detail-I-J, I, J)
            local K = Detail - I - J
            local X = (A[1] * K + B[1] * I + C[1] * J) / Detail
            local Y = (A[2] * K + B[2] * I + C[2] * J) / Detail
            local Z = (A[3] * K + B[3] * I + C[3] * J) / Detail
            return Normalize(X, Y, Z)
        end

        for I = 0, Detail - 1 do
            for J = 0, Detail - 1 - I do
                -- upward triangle
                Out[#Out + 1] = { Get(I, J), Get(I + 1, J), Get(I, J + 1) }
                -- downward triangle
                if I + J < Detail - 1 then
                    Out[#Out + 1] = { Get(I + 1, J), Get(I + 1, J + 1), Get(I, J + 1) }
                end
            end
        end
    end

    return { Faces = Out }
end

return Enum