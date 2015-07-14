# Original ported from:
#
# string_score.js: String Scoring Algorithm 0.1.10
#
# http://joshaven.com/string_score
# https://github.com/joshaven/string_score
#
# Copyright (C) 2009-2011 Joshaven Potter <yourtech@gmail.com>
# Special thanks to all of the contributors listed here https://github.com/joshaven/string_score
# MIT license: http://www.opensource.org/licenses/mit-license.php
#
# Date: Tue Mar 1 2011

PathSeparator = require('path').sep

exports.basenameScore = (string, query, score) ->
  index = string.length - 1
  index-- while string[index] is PathSeparator # Skip trailing slashes
  slashCount = 0
  lastCharacter = index
  base = null
  while index >= 0
    if string[index] is PathSeparator
      slashCount++
      base ?= string.substring(index + 1, lastCharacter + 1)
    else if index is 0
      if lastCharacter < string.length - 1
        base ?= string.substring(0, lastCharacter + 1)
      else
        base ?= string
    index--

  # Basename matches count for more.
  if base is string
    score *= 2
  else if base
    score += exports.score(base, query)

  # Shallow files are scored higher
  segmentCount = slashCount + 1
  depth = Math.max(1, 10 - segmentCount)
  score *= depth * 0.01
  score

exports.score = (string, query) ->
  return 1 if string is query

  # Return a perfect score if the file name itself matches the query.
  return 1 if queryIsLastPathSegment(string, query)

  totalCharacterScore = 0
  queryLength = query.length
  stringLength = string.length

  indexInQuery = 0
  indexInString = 0

  while indexInQuery < queryLength
    character = query[indexInQuery++]
    lowerCaseIndex = string.indexOf(character.toLowerCase())
    upperCaseIndex = string.indexOf(character.toUpperCase())
    minIndex = Math.min(lowerCaseIndex, upperCaseIndex)
    minIndex = Math.max(lowerCaseIndex, upperCaseIndex) if minIndex is -1
    indexInString = minIndex
    return 0 if indexInString is -1

    characterScore = 0.1

    # Same case bonus.
    characterScore += 0.1 if string[indexInString] is character

    if indexInString is 0 or string[indexInString - 1] is PathSeparator
      # Start of string bonus
      characterScore += 0.8
    else if string[indexInString - 1] in ['-', '_', ' ']
      # Start of word bonus
      characterScore += 0.7

    # Trim string to after current abbreviation match
    string = string.substring(indexInString + 1, stringLength)

    totalCharacterScore += characterScore

  queryScore = totalCharacterScore / queryLength
  ((queryScore * (queryLength / stringLength)) + queryScore) / 2

queryIsLastPathSegment = (string, query) ->
  if string[string.length - query.length - 1] is PathSeparator
    string.lastIndexOf(query) is string.length - query.length


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