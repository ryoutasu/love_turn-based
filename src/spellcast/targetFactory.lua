TargetFactory = {}

function TargetFactory.enemy(target)
    if target.actor and not target.actor.is_player then
        return true
    end
    return false
end

function TargetFactory.ally(target)
    if target.actor and target.actor.is_player then
        return true
    end
    return false
end

function TargetFactory.any(target)
    return true
end