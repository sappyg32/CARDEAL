local cam, running, gEntity = nil, false, nil
local camGen = 0

local angleY, angleZ = 30.0, 0.0
local gRadius, targetRadius = 5.0, 5.0
local targetAngleY, targetAngleZ = angleY, angleZ

local gRadiusMin, gRadiusMax = 2.5, 10.0

local lastCamPosition = nil
local lastAngleY, lastAngleZ = angleY, angleZ

local function cos(d) return math.cos(math.rad(d)) end
local function sin(d) return math.sin(math.rad(d)) end
local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function lerp(a, b, t) return a + (b - a) * t end

local function setCamPosition()
    local pos = GetEntityCoords(gEntity)
    local caZ, caY, saZ, saY = cos(angleZ), cos(angleY), sin(angleZ), sin(angleY)
    local offset = vec3(
      caZ * caY * gRadius,
      saZ * caY * gRadius,
      saY * gRadius
    )
    local camPos = pos + offset

    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, pos.x, pos.y, pos.z + 0.5)

    lastCamPosition = camPos
    lastAngleY, lastAngleZ = angleY, angleZ
end

local function cameraLoop(myGen)
    while running and myGen == camGen do
        local dt    = GetFrameTime()
        local speed = dt * 3.0

        angleY  = lerp(angleY,  targetAngleY, speed)
        angleZ  = lerp(angleZ,  targetAngleZ, speed)
        gRadius = lerp(gRadius, targetRadius, speed)

        angleY  = clamp(angleY, 0.0, 89.0)
        gRadius = clamp(gRadius, gRadiusMin, gRadiusMax)

        setCamPosition()
        Wait(0)
    end
end

local function zoomIn()  targetRadius = clamp(targetRadius - 0.95, gRadiusMin, gRadiusMax) end
local function zoomOut() targetRadius = clamp(targetRadius + 0.95, gRadiusMin, gRadiusMax) end
local function rotateY(d) targetAngleY = clamp(targetAngleY + d, 0.0, 89.0) end
local function rotateZ(d) targetAngleZ = targetAngleZ + d end

RegisterNUICallback("sendKeyInput", function(data, cb)
    cb(1)
    if     data.action == 'w' then rotateY(-10)
    elseif data.action == 's' then rotateY( 10)
    elseif data.action == 'a' then rotateZ(-15)
    elseif data.action == 'd' then rotateZ( 15)
    elseif data.action == 'q' then zoomIn()
    elseif data.action == 'e' then zoomOut()
    end
end)

function startDragCam(entity, opts)
    if running then
        stopDragCam()
    end
    running       = true
    camGen        = camGen + 1
    local myGen   = camGen
    gEntity       = entity

    targetRadius  = opts and opts.initial or 5.0
    gRadius       = targetRadius
    gRadiusMin    = opts and opts.min or 2.5
    gRadiusMax    = opts and opts.max or 10.0

    angleY, angleZ = lastAngleY, lastAngleZ
    targetAngleY, targetAngleZ = angleY, angleZ

    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)

    if lastCamPosition then
        SetCamCoord(cam, lastCamPosition.x, lastCamPosition.y, lastCamPosition.z)
        local pos = GetEntityCoords(gEntity)
        PointCamAtCoord(cam, pos.x, pos.y, pos.z + 0.5)
    else
        setCamPosition()
    end

    RenderScriptCams(true, true, 0, true, false)
    CreateThread(function() cameraLoop(myGen) end)
end

function stopDragCam()
    if not running then return end
    running = false
    camGen = camGen + 1

    RenderScriptCams(false, true, 0, true, false)
    if cam then
        DestroyCam(cam, true)
        cam = nil
    end
end
