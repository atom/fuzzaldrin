# A match list is an array of indexes to characters that match.
# This file should closely follow `scorer` except that it returns an array
# of indexes instead of a score.

exports.basenameMatch = (string, query) ->
  index = string.length - 1
  index-- while string[index] is '/' # Skip trailing slashes
  slashCount = 0
  lastCharacter = index
  base = null
  while index >= 0
    if string[index] is '/'
      slashCount++
      base ?= string.substring(index + 1, lastCharacter + 1)
    else if index is 0
      if lastCharacter < string.length - 1
        base ?= string.substring(0, lastCharacter + 1)
      else
        base ?= string
    index--

  exports.match(base, query, string.length - base.length)


exports.match = (string, query, stringOffset=0) ->
  return [stringOffset...stringOffset + string.length] if string is query

  queryLength = query.length
  stringLength = string.length

  indexInQuery = 0
  indexInString = 0

  matches = []

  while indexInQuery < queryLength
    character = query[indexInQuery++]
    lowerCaseIndex = string.indexOf(character.toLowerCase())
    upperCaseIndex = string.indexOf(character.toUpperCase())
    minIndex = Math.min(lowerCaseIndex, upperCaseIndex)
    minIndex = Math.max(lowerCaseIndex, upperCaseIndex) if minIndex is -1
    indexInString = minIndex
    return [] if indexInString is -1

    matches.push(stringOffset + indexInString)

    # Trim string to after current abbreviation match
    stringOffset += indexInString + 1
    string = string.substring(indexInString + 1, stringLength)

  matches
