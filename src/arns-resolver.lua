local json = require('json')

-- Constants
-- Used to determine when to require name resolution
ID_TTL_MS = 24 * 60 * 60 * 1000    -- 24 hours by default
DATA_TTL_MS = 24 * 60 * 60 * 1000  -- 24 hours by default
OWNER_TTL_MS = 24 * 60 * 60 * 1000 -- 24 hours by default

-- URL configurations
SW_CACHE_URL = "https://api.arns.app/v1/contract/"

-- Process IDs for interacting with other services or processes
ARNS_PROCESS_ID = "TyduW6spZTr3gkdIsdktduJhgtilaR_ex5JukK8gI9o"
_0RBIT_SEND_PROCESS_ID = "WSXUI2JjYUldJ7CKq9wE1MGwXs-ldzlUlHOQszwQe0s"
_0RBIT_RECEIVE_PROCESS_ID = "8aE3_6NJ_MU_q3fbhz2S6dA8PKQOSCe95Gt7suQ3j7U"

-- Initialize the NAMES and ID_NAME_MAPPING tables
NAMES = NAMES or {}
ID_NAME_MAPPING = ID_NAME_MAPPING or {}
Now = Now or 0

--- Splits a string into two parts based on the last underscore character, intended to separate ARNS names into undername and rootname components.
-- @param str The string to be split.
-- @return Two strings: the rootname (before the last underscore) and the undername (after the last underscore).
-- If no underscore is found, returns the original string and nil.
function splitIntoTwoNames(str)
    -- Pattern explanation:
    -- (.-) captures any character as few times as possible up to the last underscore
    -- _ captures the underscore itself
    -- ([^_]+)$ captures one or more characters that are not underscores at the end of the string
    local underName, rootName = str:match("(.-)_([^_]+)$")

    if underName and rootName then
        return tostring(rootName), tostring(underName)
    else
        -- If the pattern does not match (e.g., there's no underscore in the string),
        -- return the original string as the first chunk and nil as the second
        return str, nil
    end
end

-- Metatable for ARNS table to handle indexing of keys
local arnsMeta = {
    -- Define behavior for indexing keys not present in ARNS table
    __index = function(t, key)
        -- Check if key is "resolve"
        if key == "resolve" then
            -- Return a function to resolve names
            return function(name)
                -- Lowercase the name for consistency
                name = string.lower(name)
                -- Send a message to resolve the name
                ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                -- Return a message indicating the name for which information is being fetched
                return "Getting information for name: " .. name
            end
        elseif key == "data" then  -- Check if key is "data"
            -- Return a function to fetch data for names
            return function(name)
                -- Lowercase the name for consistency
                name = string.lower(name)
                -- Split the name into root and under names
                local rootName, underName = splitIntoTwoNames(name)
                -- Check if rootName is not found in NAMES table
                if NAMES[rootName] == nil then
                    -- Send a message to resolve the rootName
                    ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = rootName })
                    -- Print a message indicating that the name is being resolved
                    print(name .. ' has not been resolved yet.  Resolving now...')
                    return nil  -- Return nil as data is not available yet
                -- Check if rootName is found and underName is nil
                elseif rootName and underName == nil then
                    -- Check if rootName process records are available and are stale
                    if NAMES[rootName].process and NAMES[rootName].process.records['@'] then
                        -- Check if the data is stale and needs refreshing
                        if Now - NAMES[rootName].process.lastUpdated >= DATA_TTL_MS then
                            -- Send a message to refresh the data
                            ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                            -- Print a message indicating data is stale and being refreshed
                            print(name .. ' is stale.  Refreshing name process now...')
                            return nil  -- Return nil as data is being refreshed
                        else
                            -- Return the transaction ID
                            return NAMES[rootName].process.records['@'].transactionId
                        end
                    -- Check if rootName contract records are available and are stale
                    elseif NAMES[rootName].contract and NAMES[rootName].contract.records['@'] then
                        -- Check if the data is stale and needs refreshing
                        if Now - NAMES[rootName].contract.lastUpdated >= DATA_TTL_MS then
                            -- Send a message to refresh the data
                            ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                            -- Print a message indicating data is stale and being refreshed
                            print(name .. ' is stale.  Refreshing name contract now...')
                            return nil  -- Return nil as data is being refreshed
                        else
                            -- Return the transaction ID or contract record
                            return NAMES[rootName].contract.records['@'].transactionId or
                                NAMES[rootName].contract.records['@'] or
                                nil
                            -- Comment explaining the purpose of capturing old ANT contracts
                        end
                    end
                -- Check if both rootName and underName are present
                elseif rootName and underName then
                    -- Check if rootName process records for underName are available and are stale
                    if NAMES[rootName].process and NAMES[rootName].process.records[underName] then
                        -- Check if the data is stale and needs refreshing
                        if Now - NAMES[rootName].process.lastUpdated >= DATA_TTL_MS then
                            -- Send a message to refresh the data
                            ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                            -- Print a message indicating data is stale and being refreshed
                            print(name .. ' is stale.  Refreshing name process now...')
                            return nil  -- Return nil as data is being refreshed
                        else
                            -- Return the transaction ID for the underName
                            return NAMES[rootName].process.records[underName].transactionId
                        end
                    -- Check if rootName contract records for underName are available and are stale
                    elseif NAMES[rootName].contract and NAMES[rootName].contract.records[underName] then
                        -- Check if the data is stale and needs refreshing
                        if Now - NAMES[rootName].contract.lastUpdated >= DATA_TTL_MS then
                            -- Send a message to refresh the data
                            ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                            -- Print a message indicating data is stale and being refreshed
                            print(name .. ' is stale.  Refreshing name contract now...')
                            return nil  -- Return nil as data is being refreshed
                        else
                            -- Return the transaction ID or contract record for the underName
                            return NAMES[rootName].contract.records[underName].transactionId or
                                NAMES[rootName].contract.records[underName]
                            -- Comment explaining the purpose of capturing old ANT contracts
                        end
                    else
                        return nil  -- Return nil if data is not available
                    end
                end
            end
        elseif key == "owner" then  -- Check if key is "owner"
            -- Return a function to fetch owner for names
            return function(name)
                -- Lowercase the name for consistency
                name = string.lower(name)
                -- Split the name into root and under names
                local rootName, underName = splitIntoTwoNames(name)
                -- Check if rootName is not found in NAMES table
                if NAMES[rootName] == nil then
                    -- Send a message to resolve the rootName
                    ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = rootName })
                    -- Print a message indicating that the name is being resolved
                    print(name .. ' has not been resolved yet.  Cannot get owner.  Resolving now...')
                    return nil  -- Return nil as owner data is not available yet
                -- Check if rootName process owner data is available and is stale
                elseif NAMES[rootName].process and NAMES[rootName].process.owner then
                    -- Check if the owner data is stale and needs refreshing
                    if Now - NAMES[rootName].process.lastUpdated >= OWNER_TTL_MS then
                        -- Send a message to refresh the data
                        ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                        -- Print a message indicating owner data is stale and being refreshed
                        print(name .. ' is stale.  Refreshing name process now...')
                        return nil  -- Return nil as owner data is being refreshed
                    else
                        -- Return the owner information
                        return NAMES[rootName].process.owner
                    end
                -- Check if rootName contract owner data is available and is stale
                elseif NAMES[rootName].contract and NAMES[rootName].contract.owner then
                    -- Check if the owner data is stale and needs refreshing
                    if Now - NAMES[rootName].contract.lastUpdated >= OWNER_TTL_MS then
                        -- Send a message to refresh the data
                        ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                        -- Print a message indicating owner data is stale and being refreshed
                        print(name .. ' is stale.  Refreshing name contract now...')
                        return nil  -- Return nil as owner data is being refreshed
                    else
                        -- Return the owner information
                        return NAMES[rootName].contract.owner
                    end
                else
                    return nil  -- Return nil if owner data is not available
                end
            end
        elseif key == "id" then  -- Check if key is "id"
            -- Return a function to fetch id for names
            return function(name)
                -- Lowercase the name for consistency
                name = string.lower(name)
                -- Split the name into root and under names
                local rootName, underName = splitIntoTwoNames(name)
                -- Check if rootName is not found in NAMES table
                if NAMES[rootName] == nil then
                    -- Send a message to resolve the rootName
                    ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                    -- Print a message indicating that the name is being resolved
                    print(name .. ' has not been resolved yet.  Cannot get id.  Resolving now...')
                    return nil  -- Return nil as id data is not available yet
                -- Check if the data is stale and needs refreshing
                elseif Now - NAMES[rootName].lastUpdated >= ID_TTL_MS then
                    -- Send a message to refresh the data
                    ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                    -- Print a message indicating data is stale and being refreshed
                    print(name .. ' is stale.  Refreshing name data now...')
                    return nil  -- Return nil as id data is being refreshed
                else
                    -- Return the processId or contractTxId based on availability
                    return NAMES[rootName].processId or NAMES[rootName].contractTxId or nil
                end
            end
        elseif key == "clear" then  -- Check if key is "clear"
            -- Clear the NAMES table and return a message
            NAMES = {}
            return 'ArNS local name cache cleared.'
        else
            return nil  -- Return nil for unrecognized keys
        end
    end
}

-- Set ARNS table with the defined metatable
ARNS = setmetatable({}, arnsMeta)

--- Requests JSON data from a specified URL via the Orbit process, an external service.
-- @param url The URL from which JSON data is to be fetched.
function fetchJsonDataFromOrbit(url)
    -- Validate URL to prevent sending invalid requests
    if type(url) ~= "string" or url == "" then
        print("Invalid URL provided for fetching JSON data.")
        return
    end
    -- Send a request to the Orbit process with the specified URL.
    ao.send({ Target = _0RBIT_SEND_PROCESS_ID, Action = "Get-Real-Data", Url = url })
end

--- Determines if a given message is a record response from the ARNS process.
-- @param msg The message to evaluate.
-- @return boolean True if the message is from the ARNS process and action is 'Record-Resolved', otherwise false.
function isArNSGetRecordMessage(msg)
    if msg.From == ARNS_PROCESS_ID and msg.Action == "Record-Resolved" then
        return true
    else
        return false
    end
end

--- Determines if a message is an 'Info' message from an ANT or related process.
-- Checks if the sender's ID exists within the ID_NAME_MAPPING.
-- @param msg The message object to check.
-- @return boolean True if the sender's ID is recognized, false otherwise.
function isANTInfoMessage(msg)
    if ID_NAME_MAPPING[msg.From] then
        return true
    else
        return false
    end
end

--- Determines if a message is from the 0RBIT process with a 'Receive-data-feed' action.
-- @param msg The message object to check.
-- @return boolean True if the message is from the 0RBIT process and has the specified action, false otherwise.
function is0rbitMessage(msg)
    if msg.From == _0RBIT_RECEIVE_PROCESS_ID and msg.Action == 'Receive-data-feed' then
        return true
    else
        return false
    end
end

Handlers.prepend(
    "ArNS-Timers",
    function(msg)
        return "continue"
    end,
    function(msg)
        Now = msg.Timestamp
    end
)

--- Handles received ArNS "Record-Resolved" messages by updating the local NAMES table.
-- Updates or initializes the record for the given name with the latest information.
-- Fetches additional information from SmartWeave Cache or ANT-AO process if necessary.
Handlers.add("ReceiveArNSGetRecordMessage", isArNSGetRecordMessage, function(msg)
    local data, err = json.decode(msg.Data)
    if not data or err then
        print("Error decoding JSON data: ", err)
        return
    end

    -- Update or initialize the record with the latest information.
    NAMES[msg.Tags.Name] = NAMES[msg.Tags.Name] or {
        lastUpdated = msg.Timestamp,
        contractTxId = data.contractTxId,
        -- Assuming these fields are placeholders for future updates.
        contractOwner = nil,
        contract = nil,
        processOwner = nil,
        process = nil
    }
    NAMES[msg.Tags.Name].processId = data.processId
    NAMES[msg.Tags.Name].record = data
    NAMES[msg.Tags.Name].lastUpdated = msg.Timestamp

    print("Updated " .. msg.Tags.Name .. " with the latest ArNS-AO Registry info!")

    -- Fetch additional information if contractTxId is provided.
    if data.contractTxId then
        local url = SW_CACHE_URL .. data.contractTxId
        print("...fetching more info from SmartWeave Cache (via 0rbit): " .. url)
        fetchJsonDataFromOrbit(url)
        ID_NAME_MAPPING[data.contractTxId] = msg.Tags.Name
    end

    -- Request more information if processId is provided and not empty.
    if data.processId then
        print("...fetching more info from ANT-AO process: " .. data.processId)
        ID_NAME_MAPPING[data.processId] = msg.Tags.Name
        ao.send({ Target = data.processId, Action = "Info" })
    end
end)

--- Updates stored information with the latest data from ANT-AO process "Info-Notice" messages.
-- @param msg The received message object containing updated process info.
Handlers.add("ReceiveANTProcessInfoMessage", isANTInfoMessage, function(msg)
    if msg.Action == 'Info-Notice' and NAMES[ID_NAME_MAPPING[msg.From]] then
        local nameKey = ID_NAME_MAPPING[msg.From]
        local updatedInfo = NAMES[nameKey]

        -- Attempt to decode the JSON data from the message.
        local processInfo, err = json.decode(msg.Data)
        if err then
            print("Error decoding process info: ", err)
            return
        end

        -- Ensure the decoded data is a valid table before updating.
        if type(processInfo) == "table" then
            updatedInfo.process = processInfo
            updatedInfo.process.owner = msg.Tags.ProcessOwner
            updatedInfo.process.lastUpdated = msg.Timestamp
            NAMES[nameKey] = updatedInfo
            print("Updated " .. nameKey .. " with the latest ANT-AO process info!")
        else
            print("Invalid process info format received from " .. nameKey)
        end

        -- Clear the mapping after updating to prevent redundant updates.
        ID_NAME_MAPPING[msg.From] = nil
    end
end)

--- Processes messages from the 0rbit process to update contract information stored in NAMES.
-- @param msg The message object received from the 0rbit process.
Handlers.add("Receive0rbitMessage", is0rbitMessage, function(msg)
    -- Decode the JSON data from the message.
    local data, err = json.decode(msg.Data)
    if err then
        print("Error decoding data from 0rbit message: ", err)
        return
    end

    -- Validate that the decoded data contains a contractTxId that is currently being tracked.
    local nameKey = ID_NAME_MAPPING[data.contractTxId]
    if nameKey and NAMES[nameKey] then
        local updatedInfo = NAMES[nameKey]

        -- Ensure the data contains 'state' information for the contract before updating.
        if type(data.state) == "table" then
            updatedInfo.contract = data.state
            updatedInfo.contract.owner = data.state.owner
            updatedInfo.contract.lastUpdated = msg.Timestamp
            NAMES[nameKey] = updatedInfo
            print("Updated " .. nameKey .. " with the latest info from SmartWeave Cache (via 0rbit)!")
        else
            print("Received 0rbit message with invalid or missing 'state' information for contractTxId: " ..
                tostring(data.contractTxId))
        end

        -- Clear the mapping to prevent repeated updates for the same contractTxId.
        ID_NAME_MAPPING[data.contractTxId] = nil
    else
        print("Received 0rbit message for an untracked or invalid contractTxId: " .. tostring(data.contractTxId))
    end
end)
