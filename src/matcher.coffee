# A match list is an array of indexes to characters that match.
# This file should closely follow `scorer` except that it returns an array
# of indexes instead of a score.

PathSeparator = require('path').sep
scorer = require './scorer'


exports.basenameMatch = (string, query) ->

  # Skip trailing slashes
  end = string.length - 1
  end-- while string[end] is PathSeparator

  # Get position of basePath of string. If no PathSeparator, no base path exist.
  basePos = string.lastIndexOf(PathSeparator, end)
  return [] if (basePos == -1)

  # Get basePath match
  exports.match(string.substring(basePos + 1, end + 1), query, basePos+1)


exports.match = (string, query, stringOffset=0) ->
  return scorer.align(string, query, stringOffset)


# Fast but greedy algorithm, IE it report the first occurrence of char
# even if a latter occurrence will score more
exports.fastMatch = (string, query, stringOffset=0) ->
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


#
# Combine two sorted sequence and remove duplicate
# (use to combine two match)
#

exports.mergeSorted = (a, b) ->

  out = []
  m = a.length
  n = b.length

  return a.slice() if n == 0
  return b.slice() if m == 0

  i = -1
  j = 0
  bj = b[0]

  while ++i < m
    ai = a[i]

    while bj <= ai and ++j < n
      if bj < ai
        out.push bj
      bj = b[j]

    out.push ai

  while j < n
    out.push b[j++]

  return out
