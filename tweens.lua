---@name Tweens
---@author AstricUnion
---@shared

---@alias tweenfun fun(process: number): boolean? Tween function. Gets process, returns boolean, is tween ended

---@class StartedTween
---@field fun tweenfun Function to handle tween
---@field startedAt number When this tween started, relative to curtime
---@field processAtPause number Actual process at pausing
---@field isPaused boolean Is tween paused
---@field loop boolean Is tween looped

---Class to manipulate tweens
---@class tween
---@field started table<number, StartedTween>
---@field id number ID of last tween
local tween = {}
tween.started = {}
tween.id = 0


---@class ParamProperty
---@field get fun(self: Entity)
---@field set fun(self: Entity, value: any)
---@field diff fun(from: any, to: any)

local function modAngle(tbl, mod)
    return Angle(tbl.p % mod, tbl.y % mod, tbl.r % mod)
end

-- https://stackoverflow.com/questions/2708476/rotation-interpolation#14498790
---@param b Angle
local function angleDiff(a, b)
    local shortest = modAngle(modAngle(b - a, 360) + Angle(540), 360) - Angle(180)
    return shortest
end

---@enum ParamProperties
tween.ParamProperties = {
    NONE = {
        get = function() end,
        set = function() end
    },
    POS = {
        get = function(x) return x:getPos() end,
        set = function(x, set) x:setPos(set) end
    },
    ANGLES = {
        get = function(x) return x:getAngles() end,
        set = function(x, set) x:setAngles(set) end,
        diff = angleDiff
    },
    LOCALPOS = {
        get = function(x) return x:getLocalPos() end,
        set = function(x, set) x:setLocalPos(set) end
    },
    LOCALANGLES = {
        get = function(x) return x:getLocalAngles() end,
        set = function(x, set) x:setLocalAngles(set) end,
        diff = angleDiff
    },
    COLOR = {
        get = function(x) return x:getColor() end,
        set = function(x, set) x:setColor(set) end
    },
    SCALE = {
        get = function(x) return x:getScale() end,
        set = function(x, set) x:setScale(set) end
    },
    ANGULARVELOCITY = {
        get = function(x) return x:getAngleVelocity() end,
        set = function(x, set) x:setAngleVelocity(set) end
    },
    -- Only with holograms!
    LOCALANGULARVELOCITY = {
        get = function(x) return x.angular end,
        set = function(x, set)
            if !x.angular then x.angular = Vector() end
            x:setLocalAngularVelocity(set)
            x.angular = set
        end
    },
    VELOCITY = {
        get = function(x) return x:getVelocity() end,
        set = function(x, set) x:setVelocity(set) end
    },
    ADDVELOCITY = {
        get = function(x) return x:getVelocity() end,
        set = function(x, set) x:addVelocity(set) end
    },
}


---@class TweenParam
---@field startAt number?
---@field endAt number?
---@field entity Entity?
---@field property ParamProperty?
---@field from (any|fun(process: number): any)?
---@field to (any|fun(process: number): any)?
---@field easing fun(process: number)?

local function linear(x) return x end

---[SHARED] Create new parameter change
---@param tbl TweenParam
---@return tweenfun
function tween.param(tbl)
    local startAt = tbl.startAt or tbl[1] or 0
    local endAt = tbl.endAt or tbl[2]
    local ent = tbl.entity or tbl[3]
    local property = tbl.property or tbl[4] or tween.ParamProperties.NONE
    local from = tbl.from or tbl[5]
    local to = tbl.to or tbl[6]
    local easing = tbl.easing or tbl[7] or linear
    return function(process)
        if process < startAt then return end
        if ent and !isValid(ent) then return true end
        from = from or property.get(ent)
        local duration = endAt - startAt
        local localProcess = math.min(process - startAt, duration)
        local fraction = localProcess / duration
        local startValue = isfunction(from) and from(localProcess) or from
        local endValue = isfunction(to) and to(localProcess) or to
        local change = property.diff and property.diff(startValue, endValue) or endValue - startValue
        local eased = easing(fraction)
        local tweened = startValue + change * eased
        property.set(ent, tweened)
        if fraction == 1 then
            from = nil
            return true
        end
    end
end


---@class FCurveKeyframe
---@field [1] number[] Left handle
---@field [2] number[] Control point
---@field [3] number[] Right handle

---@class TweenFCurveParam
---@field startAt number?
---@field endAt number?
---@field entity Entity?
---@field property ParamProperty?
---@field type FCurveValueType?
---@field keyframes table<string|number, FCurveKeyframe[]>?
---@field scale number? Scale of animation


local function longBezier(process, keyframes)
    local len = #keyframes
    if len < 2 then return keyframes[1] and keyframes[1][1][2] or 0 end
    local globalProcess = math.min(process * len, len - 1)
    local currentCurve = process == 0 and 1 or math.ceil(globalProcess)

    local curve = keyframes[currentCurve]
    local nextCurve = keyframes[currentCurve + 1]
    local start = Vector(curve[2][1], curve[2][2])
    local tangent1 = Vector(curve[3][1], curve[3][2])
    local tangent2 = Vector(nextCurve[1][1], nextCurve[1][2])
    local _end = Vector(nextCurve[2][1], nextCurve[2][2])

    local value = math.bezierVectorCubic(globalProcess - currentCurve + 1, start, tangent1, tangent2, _end)

    return value.y
end

local function blenderRotation(p, y, r)
    local ang = Angle()
    ang = ang:rotateAroundAxis(Vector(0, 1, 0), p)
    ang = ang:rotateAroundAxis(Vector(0, 0, 1), y)
    ang = ang:rotateAroundAxis(Vector(1, 0, 0), r)
    return ang
end

local function blenderRotationRad(p, y, r)
    local ang = Angle()
    ang = ang:rotateAroundAxis(Vector(0, 1, 0), nil, p)
    ang = ang:rotateAroundAxis(Vector(0, 0, 1), nil, y)
    ang = ang:rotateAroundAxis(Vector(1, 0, 0), nil, r)
    return ang
end

tween.blenderRotation = blenderRotation
tween.blenderRotationRad = blenderRotationRad


---@alias FCurveValueType
---| '"number"'
---| '"location"'
---| '"rotation_euler"'
---| '"rotation_quaternion"'
local FCurveValueType = {
    ["number"] = function(process, keyframes, scale)
        return longBezier(process, keyframes[1]) * scale
    end,
    ["location"] = function(process, keyframes, scale)
        local x = longBezier(process, keyframes.x or keyframes[1] or {})
        local y = longBezier(process, keyframes.y or keyframes[2] or {})
        local z = longBezier(process, keyframes.z or keyframes[3] or {})
        local pos = Vector(x, y, z) * scale
        return pos
    end,
    ["rotation_euler"] = function(process, keyframes, scale)
        local p = longBezier(process, keyframes.p or keyframes[1] or {})
        local y = longBezier(process, keyframes.y or keyframes[2] or {})
        local r = longBezier(process, keyframes.r or keyframes[3] or {})
        local ang = blenderRotation(p, y, r)
        return ang
    end,
    ["rotation_quaternion"] = function(process, keyframes, scale)
        local w = longBezier(process, keyframes.w or keyframes[1] or {})
        local x = longBezier(process, keyframes.x or keyframes[2] or {})
        local y = longBezier(process, keyframes.y or keyframes[3] or {})
        local z = longBezier(process, keyframes.z or keyframes[4] or {})
        local quart = Quaternion(w, x, y, z)
        local ang = quart:getEulerAngle()
        return blenderRotation(ang.p, ang.y, ang.r)
    end
}

---[SHARED] Create new F-Curve parameter change
---@param tbl TweenFCurveParam
---@return tweenfun
function tween.fcurveParam(tbl)
    local startAt = tbl.startAt or tbl[1] or 0
    local endAt = tbl.endAt or tbl[2]
    local ent = tbl.entity or tbl[3]
    local property = tbl.property or tbl[4] or tween.ParamProperties.NONE
    local type = tbl.type or tbl[5] or "number"
    local keyframes = tbl.keyframes or tbl[6] or throw("There's no keyframes!")
    local scale = tbl.scale or tbl[7] or 1
    return function(process)
        if process < startAt then return end
        if ent and !isValid(ent) then return true end
        local duration = endAt - startAt
        local fraction = math.min(math.min(process - startAt, duration) / duration, 1)
        local tweened = FCurveValueType[type](fraction, keyframes, scale)
        property.set(ent, tweened)
        if fraction == 1 then
            return true
        end
    end
end



---@class TweenLerpParam
---@field startAt number?
---@field entity Entity?
---@field property ParamProperty?
---@field ratio number?
---@field to (any|fun(): any)?

local function lerpForAll(a, b, change, t)
    return t == 1 and b or a + change * t
end

---[SHARED] Create new lerp parameter change
---@param tbl TweenLerpParam
---@return tweenfun
function tween.lerpParam(tbl)
    local startAt = tbl.startAt or tbl[1] or 0
    local ent = tbl.entity or tbl[2]
    local property = tbl.property or tbl[3] or tween.ParamProperties.NONE
    local to = tbl.to or tbl[4]
    local ratio = tbl.ratio or tbl[5]
    return function(process)
        if process < startAt then return end
        if ent and !isValid(ent) then return true end
        local endValue = isfunction(to) and to() or to
        local current = property.get(ent)
        local change = property.diff and property.diff(current, endValue) or endValue - current
        local tweened = lerpForAll(current, endValue, change, ratio)
        property.set(ent, tweened)
        if current == tweened then
            return true
        end
    end
end

---[SHARED] Create new tween
---@param tbl tweenfun[]
---@return tweenfun
function tween.new(tbl)
    return function(process)
        local result = true
        for _, v in ipairs(tbl) do
            if !v(process) then
                result = false
            end
        end
        return result
    end
end

---[SHARED] Start tween in background
---@param fun tweenfun Tween function to start
---@param loop boolean? Loop this tween
---@return number id Identifier of tween to control it
function tween.start(fun, loop)
    tween.id = tween.id + 1
    tween.started[tween.id] = {
        fun = fun,
        isPaused = false,
        startedAt = timer.curtime(),
        processAtPause = 0,
        loop = loop or false
    }
    return tween.id
end

---[SHARED] Stop and remove tween
---@param id number Tween to stop
function tween.stop(id)
    tween.started[id] = nil
end

---[SHARED] Pause tween
---@param id number Tween to stop
function tween.pause(id)
    local tw = tween.started[id]
    if !tw then return end
    tw.isPaused = true
    tw.processAtPause = timer.curtime() - tw.startedAt
end

---[SHARED] Unpause tween
---@param id number Tween to stop
function tween.unpause(id)
    local tw = tween.started[id]
    if !tw then return end
    tw.isPaused = false
    tw.startedAt = timer.curtime() - tw.processAtPause
    tw.processAtPause = 0
end


local function tweenAnimations()
    local cur = timer.curtime()
    for i, v in pairs(tween.started) do
        if v.isPaused then goto cont end
        if v.fun(cur - v.startedAt) then
            if !v.loop then
                tween.started[i] = nil
            else
                v.startedAt = cur
            end
        end
        ::cont::
    end
end

hook.add("Think", "TweenAnimations", tweenAnimations)

return tween
