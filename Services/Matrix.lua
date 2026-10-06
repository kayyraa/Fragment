local Matrix = {}

local function Identity()
    return {
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1
    }
end

function Matrix.Identity()
    return Identity()
end

function Matrix.Perspective(Fovy, Aspect, Near, Far)
    local F = 1 / math.tan(Fovy / 2)
    local Nf = 1 / (Near - Far)
    return {
        F / Aspect, 0, 0, 0,
        0, F, 0, 0,
        0, 0, (Far + Near) * Nf, -1,
        0, 0, 2 * Far * Near * Nf, 0
    }
end

function Matrix.LookAt(Eye, Target, Up)
    local Zx = Eye[1] - Target[1]
    local Zy = Eye[2] - Target[2]
    local Zz = Eye[3] - Target[3]
    local Len = math.sqrt(Zx*Zx + Zy*Zy + Zz*Zz)
    if Len > 0 then Zx, Zy, Zz = Zx/Len, Zy/Len, Zz/Len end

    local Xx = Up[2]*Zz - Up[3]*Zy
    local Xy = Up[3]*Zx - Up[1]*Zz
    local Xz = Up[1]*Zy - Up[2]*Zx
    Len = math.sqrt(Xx*Xx + Xy*Xy + Xz*Xz)
    if Len > 0 then Xx, Xy, Xz = Xx/Len, Xy/Len, Xz/Len end

    local Yx = Zy*Xz - Zz*Xy
    local Yy = Zz*Xx - Zx*Xz
    local Yz = Zx*Xy - Zy*Xx

    return {
        Xx, Yx, Zx, 0,
        Xy, Yy, Zy, 0,
        Xz, Yz, Zz, 0,
        -(Xx*Eye[1] + Xy*Eye[2] + Xz*Eye[3]),
        -(Yx*Eye[1] + Yy*Eye[2] + Yz*Eye[3]),
        -(Zx*Eye[1] + Zy*Eye[2] + Zz*Eye[3]),
        1
    }
end

function Matrix.Translate(X, Y, Z)
    return {
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        X,Y,Z,1
    }
end

function Matrix.Scale(Sx, Sy, Sz)
    Sy = Sy or Sx
    Sz = Sz or Sx
    return {
        Sx,0,0,0,
        0,Sy,0,0,
        0,0,Sz,0,
        0,0,0,1
    }
end

function Matrix.RotateX(Angle)
    local C, S = math.cos(Angle), math.sin(Angle)
    return {
        1, 0, 0, 0,
        0, C, S, 0,
        0,-S, C, 0,
        0, 0, 0, 1
    }
end

function Matrix.RotateY(Angle)
    local C, S = math.cos(Angle), math.sin(Angle)
    return {
        C, 0,-S, 0,
        0, 1, 0, 0,
        S, 0, C, 0,
        0, 0, 0, 1
    }
end

function Matrix.RotateZ(Angle)
    local C, S = math.cos(Angle), math.sin(Angle)
    return {
        C, S, 0, 0,
       -S, C, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function Matrix.Mul(A, B)
    local R = {}
    for Col = 0, 3 do
        for Row = 0, 3 do
            local Sum = 0
            for K = 0, 3 do
                Sum = Sum + A[K*4 + Row + 1] * B[Col*4 + K + 1]
            end
            R[Col*4 + Row + 1] = Sum
        end
    end
    return R
end

function Matrix.FromEulerXYZ(Rx, Ry, Rz)
    local RX = Matrix.RotateX(Rx or 0)
    local RY = Matrix.RotateY(Ry or 0)
    local RZ = Matrix.RotateZ(Rz or 0)
    return Matrix.Mul(RZ, Matrix.Mul(RY, RX))
end

function Matrix.FromTRS(Tx, Ty, Tz, Rx, Ry, Rz, Sx, Sy, Sz)
    local S = Matrix.Scale(Sx or 1, Sy or Sx or 1, Sz or Sx or 1)
    local R = Matrix.FromEulerXYZ(Rx or 0, Ry or 0, Rz or 0)
    local T = Matrix.Translate(Tx or 0, Ty or 0, Tz or 0)
    return Matrix.Mul(T, Matrix.Mul(R, S))
end

function Matrix.FromTRSdegrees(Tx, Ty, Tz, RxDeg, RyDeg, RzDeg, Sx, Sy, Sz)
    return Matrix.FromTRS(
        Tx, Ty, Tz,
        math.rad(RxDeg or 0), math.rad(RyDeg or 0), math.rad(RzDeg or 0),
        Sx, Sy, Sz
    )
end

return Matrix