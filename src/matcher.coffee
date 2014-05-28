
exports.match = (string, query) ->
  return 1 if string is query

  totalCharacterScore = 0
  queryLength = query.length
  stringLength = string.length

  indexInQuery = 0
  indexInString = 0

  matches = []
  matchedChars = []

  while indexInQuery < queryLength
    character = query[indexInQuery++]
    lowerCaseIndex = string.indexOf(character.toLowerCase())
    upperCaseIndex = string.indexOf(character.toUpperCase())
    minIndex = Math.min(lowerCaseIndex, upperCaseIndex)
    minIndex = Math.max(lowerCaseIndex, upperCaseIndex) if minIndex is -1
    indexInString = minIndex
    return [string] if indexInString is -1

    before = string.substring(0, indexInString)
    unless matchedChars.length
      matches.push(before)

    if indexInString isnt 0 and matchedChars.length > 1
      matches.push(matchedChars.join(''))
      matches.push(before)
      matchedChars = []

    matchedChars.push(string[indexInString])

    if indexInQuery is queryLength
      matches.push(matchedChars.join(''))
      matches.push(string.substring(indexInString + 1, stringLength))


    # Trim string to after current abbreviation match
    string = string.substring(indexInString + 1, stringLength)

  matches
