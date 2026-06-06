---@name Tweens
---@author AstricUnion
---@shared

---@alias tweenfun fun(process: number): boolean? Tween function. Gets process, returns boolean, is tween ended

---@class StartedTween
---@field fun tweenfun Function to handle tween
---@field startedAt number When this tween started, relative to curtime
---@field processAtPause number Actual process at pausing
---@field isPaused boolean Is tween paused

---Class to manipulate tweens
---@class tween
---@field started table<number, StartedTween>
local tween = {}
tween.started = {}


---@class ParamProperty
---@field get fun(self: Entity)
---@field set fun(self: Entity, value: any)

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
        set = function(x, set) x:setAngles(set) end
    },
    LOCALPOS = {
        get = function(x) return x:getLocalPos() end,
        set = function(x, set) x:setLocalPos(set) end
    },
    LOCALANGLES = {
        get = function(x) return x:getLocalAngles() end,
        set = function(x, set) x:setLocalAngles(set) end
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
---@field from (any|fun(): any)?
---@field to (any|fun(): any)?
---@field easing fun(process: number)?


---[SHARED] Create new parameter change
---@param tbl TweenParam
---@return tweenfun
function tween.param(tbl)
    local startAt = tbl.startAt or tbl[1] or 0
    local endAt = tbl.endAt or tbl[2]
    local ent = tbl.entity or tbl[3]
    local property = tbl.property or tbl[4] or tween.ParamProperties.NONE
    local from = tbl.from or tbl[5] or property.get(ent)
    local to = tbl.to or tbl[6]
    local easing = tbl.easing or tbl[7]
    return function(process)
        if process < startAt then return end
        local duration = endAt - startAt
        local fraction = math.min((process - startAt) / duration, 1)
        from = isfunction(from) and from() or from
        to = isfunction(to) and to() or to
        local change = to - from
        local eased = easing(fraction)
        local tweened = from + change * eased
        property.set(ent, tweened)
        if fraction == 1 then
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
---@return number id Identifier of tween to control it
function tween.start(fun)
    local id = #tween.started+1
    tween.started[id] = {
        fun = fun,
        isPaused = false,
        startedAt = timer.curtime(),
        processAtPause = 0
    }
    return id
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
            tween.started[i] = nil
        end
        ::cont::
    end
end

hook.add(SERVER and "Think" or "RenderOffscreen", "TweenAnimations", tweenAnimations)

return tween
