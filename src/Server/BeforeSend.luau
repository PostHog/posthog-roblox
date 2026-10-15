--!nonstrict

local BeforeSend = {}

function BeforeSend.run(hook, event, logger)
    if not hook then
        return event
    end

    local ok, result = pcall(hook, event)
    if not ok then
        logger:error(`beforeSend threw, dropping {event.event}: {tostring(result)}`)
        return nil
    end
    if type(result) ~= "table" then
        logger:debug(`beforeSend dropped {event.event}`)
        return nil
    end
    return result
end

return BeforeSend
