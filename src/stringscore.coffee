UnderscoreDashRegex = /[_-]/g

# Original ported from JavaScript:
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

  string = string.replace(UnderscoreDashRegex, '')

  totalCharacterScore = 0
  abbreviationLength = abbreviation.length
  stringLength = string.length

  index = 0
  while index < abbreviation.length
    character = abbreviation[index++]
    lowerCaseIndex = string.indexOf(character.toLowerCase())
    upperCaseIndex = string.indexOf(character.toUpperCase())
    minIndex = Math.min(lowerCaseIndex, upperCaseIndex)
    minIndex = Math.max(lowerCaseIndex, upperCaseIndex) if minIndex is -1
    indexInString = minIndex
    return 0 if indexInString is -1

    characterScore = 0.1

    # Same case bonus.
    characterScore += 0.1 if string[indexInString] is character

    # Consecutive letter & start-of-string Bonus
    if indexInString is 0
      # Increase the score when matching first character of the remainder of the string
      characterScore += 0.6
    else
      # Acronym Bonus
      # Weighing Logic: Typing the first character of an acronym is as if you
      # preceded it with two perfect character matches.
      characterScore += 0.8 if string[indexInString - 1] is ' '

    # Left trim the already matched part of the string
    # (forces sequential matching).
    string = string.substring(indexInString + 1, stringLength)

    totalCharacterScore += characterScore

  abbreviationScore = totalCharacterScore / abbreviationLength
  ((abbreviationScore * (abbreviationLength / stringLength)) + abbreviationScore) / 2
