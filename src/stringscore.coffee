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

module.exports = (string, abbreviation) ->
  return 1 if string is abbreviation

  totalCharacterScore = 0
  abbreviationLength = abbreviation.length
  stringLength = string.length

  indexInAbbreviation = 0
  indexInString = 0

  while indexInAbbreviation < abbreviationLength
    character = abbreviation[indexInAbbreviation++]
    lowerCaseIndex = string.indexOf(character.toLowerCase())
    upperCaseIndex = string.indexOf(character.toUpperCase())
    minIndex = Math.min(lowerCaseIndex, upperCaseIndex)
    minIndex = Math.max(lowerCaseIndex, upperCaseIndex) if minIndex is -1
    indexInString = minIndex
    return 0 if indexInString is -1

    characterScore = 0.1

    # Same case bonus.
    characterScore += 0.1 if string[indexInString] is character

    # Start of string/word bonus
    if indexInString is 0 or string[indexInString - 1] is ' '
      characterScore += 0.8

    # Left trim the already matched part of the string
    # (forces sequential matching).
    string = string.substring(indexInString + 1, stringLength)

    totalCharacterScore += characterScore

  abbreviationScore = totalCharacterScore / abbreviationLength
  ((abbreviationScore * (abbreviationLength / stringLength)) + abbreviationScore) / 2
