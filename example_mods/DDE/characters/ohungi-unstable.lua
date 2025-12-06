local mustHit = false

function charScriptStarted(char)
    mustHit = (char == 'boyfriend' and true or false)
end


function onNoteSpawn(noteData)
    if not getProperty('dad.curCharacter') == characterName then return end
    if noteData.noteType == 'Alt Animation' and noteData.mustHit == mustHit then
        setPropertyFromGroup('notes', noteData.index, 'multSpeed', 0.33)
    end
end