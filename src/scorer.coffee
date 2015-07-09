#
# Score similarity between two string
#
#  isMatch: Fast detection if all character of needle is in haystack
#  score: Find string similarity using a Smith Waterman Gotoh algorithm
#         Modified to account for programing scenarios (CamelCase folder/file.ext object.property)
#
# Copyright (C) 2015 Jean Christophe Roy and contributors
# MIT License: http://opensource.org/licenses/MIT
#
# Previous version of scorer used string_score from Joshaven Potter
# https://github.com/joshaven/string_score/


wm = 10 # base score of making a match
ws = 30 # bonus of making a separator match
wa = 20 # bonus of making an acronym match
wc = 10 # bonus for proper case

wo = -8 # penalty to open a gap
we = -2 # penalty to continue an open gap (inside a match)
wh = -0.1 # penalty for haystack size (outside match)

wst = 20 # bonus for match near start of string  (fade one per position until 0)
wex = 10 # bonus per character of an exact match. If exact coincide with prefix, bonus will be 2*wex, then it'll fade to 1*wex as string happens later.

#Note: separator are likely to trigger both a
# "acronym" and "proper case" bonus in addition of their own bonus.


separators = ' .-_/\\'
PathSeparator = require('path').sep

separator_map = ->
  sep_map = {}
  k = -1
  while ++k < separators.length
    sep_map[separators[k]] = k

  sep_map

sep_map = separator_map()

exports.score = score = (subject, query, ignore) ->

  #bypass isMatch will allow inexact match, but will be slower
  return 0 if !( subject and query and isMatch(query, subject) )

  m = query.length + 1
  n = subject.length + 1

  #Init
  vrow = new Array(n)
  gapArow = new Array(n)
  gapA = 0
  gapB = 0
  vmax = 0

  #DEBUG
  #VV = []

  #Fill with 0
  j = -1
  while ++j < n
    gapArow[j] = 0
    vrow[j] = 0

  i = 0 #1..m-1
  while ++i < m
    #foreach char of query
    gapB = 0
    vd = vrow[0]

    #DEBUG
    #VV[i] = []

    j = 0 #1..n-1
    while ++j < n
      #foreach char of subject

      # Score the options
      gapA = gapArow[j] = Math.max(gapArow[j] + we, vrow[j] + wo)
      gapB = Math.max(gapB + we, vrow[j - 1] + wo)
      align = vd + char_score(query, subject, i - 1, j - 1)
      vd = vrow[j]

      #Get the best option
      v = vrow[j] = Math.max(align, gapA, gapB, 0)

      #DEBUG
      #VV[i][j] = v

      #Record best score
      if v > vmax
        vmax = v

  #DEBUG
  #console.log(query,subject)
  #console.table(VV);


  #haystack penalty
  vmax = Math.max(vmax / 2, vmax + wh * (n - m))

  #sustring bonus, start of string bonus
  vmax += if (p = subject.toLowerCase().indexOf(query.toLowerCase())) > -1 then wex * m * (1.0 + 1.0 / (1.0 + p)) else 0

  return vmax

char_score = (query, subject, i, j) ->
  qi = query[i]
  sj = subject[j]

  if qi.toLowerCase() == sj.toLowerCase()

    #Proper casing bonus
    bonus = if qi == sj then wc else 0

    #start of string bonus
    bonus += Math.max(wst - j, 0)

    #match IS a separator
    if qi of sep_map
      return ws + bonus

    #match is first char ( place a virtual token separator before first char of string)
    return wa + bonus if ( j == 0 or i == 0)

    #get previous char
    prev_s = subject[j - 1]
    prev_q = query[i - 1]

    #match FOLLOW a separator
    return wa + bonus if ( prev_s of sep_map) or ( prev_q of sep_map )

    #match IS Capital in camelCase (preceded by lowercase)
    return wa + bonus if (sj == sj.toUpperCase() and prev_s == prev_s.toLowerCase())

    #normal Match, add proper case bonus
    return wm + bonus

  #No match, best move will be to take a gap in either query or subject.
  return -Infinity


isMatch = (query, subject) ->
  m = query.length
  n = subject.length

  if !m or !n or m > n
    return false

  lq = query.toLowerCase()
  ls = subject.toLowerCase()

  i = -1
  j = -1
  k = n - 1

  while ++i < m

    qi = lq[i]

    while ++j < n

      if ls[j] == qi
        break

      else if j == k
        return false


  true

exports.basenameScore = (string, query, score) ->

  return 0 if score == 0
  end = string.length - 1
  end-- while string[end] is PathSeparator # Skip trailing slashes

  basePos = string.lastIndexOf(PathSeparator, end)
  baseScore = if (basePos == -1) then score else Math.max(score, exports.score(string.substring(basePos + 1, end+1), query))
  score = 0.15*score + 0.85*baseScore

  score

 ###

  slashCount = 0
  baseScore = 0
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

   # Shallow files are scored higher
   score += baseScore*( 3.0 + 3.0/(3.0+slashCount) )

 ###





