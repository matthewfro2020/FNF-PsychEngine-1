local mustHit = false

function charScriptStarted(char)
    mustHit = (char == 'boyfriend' and true or false)
end

function onUpdatePost(elapsed)
    if dadName == 'cuble-gooble' then
        local antialiasing = not (getProperty('dad.curAnimName') == 'nervous' and getProperty('dad.curAnimFrame') <= 10)
        setProperty('dad.antialiasing', antialiasing)
    end
end