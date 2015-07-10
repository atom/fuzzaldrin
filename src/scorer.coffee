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
wc = 10 # bonus for proper case

wa = 20 # bonus of making an acronym match
ws = 20 # bonus of making a separator match

wo = -10 # penalty to open a gap
we = -2 # penalty to continue an open gap (inside a match)
wh = -0.1 # penalty for haystack size (outside match)

wst = 15 # bonus for match near start of string
wex = 60 # bonus per character of an exact match. If exact coincide with prefix, bonus will be 2*wex, then it'll fade to 1*wex as string happens later.

#Note: separator are likely to trigger both a
# "acronym" and "proper case" bonus in addition of their own bonus.

separators = ' .-_/\\'
PathSeparator = require('path').sep

#
# Build a hashmap of separator
#

separator_map = ->
  sep_map = {}
  k = -1
  while ++k < separators.length
    sep_map[separators[k]] = k

  return sep_map

# save hashmap in current closure
sep_map = separator_map()


# Optional chars
# Some characters of query char MUST be in subject,
# Others COULD be there or not, better Score if they are, but not blocking isMatch.
#
# For example:
# - space can be skipped in favor of a slash.
# - space like separator like in slug "-" "_" " "
#

opt_char_re = /[ \-\_]/g

#
# Main scoring algorithm
#

exports.score = score = (subject, query, ignore) ->
  m = query.length + 1
  n = subject.length + 1

  subject_lw = subject.toLowerCase()
  query_lw = query.toLowerCase()
  exact = 0

  #Exact Match => bypass (if case sensitive match)
  if ( p = subject_lw.indexOf(query_lw)) > -1

    base = wex * m

    #base bonus + position decay
    exact = base * (1.0 + 3.0 / (3.0 + p))

    #sustring happens right after a separator (prefix)
    if (p == 0 or subject[p - 1] of sep_map)
      exact += 3*base

    # last position, the +1s cancel out
    # for both the "length=<last index>+1" and the buffer=length+1
    # also m is query, so smallest of both number
    lpos = n - m

    #sustring happens right before a separator (suffix)
    if (p == lpos or subject[p + 1] of sep_map)
      exact += base

    #substring is ExactCase
    if(subject.indexOf(query) > -1)
      exact += 2*base
      return exact




  #Init
  vrow = new Array(n)
  gapArow = new Array(n)
  gapA = 0
  gapB = 0
  vmax = 0

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

    j = 0 #1..n-1
    while ++j < n
      #foreach char of subject

      # Score the options
      gapA = gapArow[j] = Math.max(gapArow[j] + we, vrow[j] + wo)
      gapB = Math.max(gapB + we, vrow[j - 1] + wo)
      align = if ( query_lw[i - 1] == subject_lw[j - 1] ) then vd + scoreMatchingChar(query, subject, i - 1, j - 1) else 0
      vd = vrow[j]

      #Get the best option (align set the lower-bound to 0)
      v = vrow[j] = Math.max(align, gapA, gapB)

      #Record best score
      if v > vmax
        vmax = v

  #haystack penalty
  vmax = Math.max(0.5 * vmax, vmax + wh * (n - m))


  return vmax+exact

#
# Compute the bonuses for two chars that are confirmed to matches in a case-insensitive way
#

scoreMatchingChar = (query, subject, i, j) ->
  qi = query[i]
  sj = subject[j]

  #Proper casing bonus
  bonus = if qi == sj then wc else 0

  #start of string bonus
  bonus += Math.floor(wst * 10.0 / (10.0 + i + j))

  #match IS a separator
  return ws + bonus if qi of sep_map

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


#
# filer query until we only get essential char
#

exports.coreChars = coreChars = (query) ->
  return query.replace(opt_char_re, '')


#
# yes/no: is all characters of query in subject, in proper order
#

exports.isMatch = isMatch = (subject, query) ->
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


  return true

#
# Score adjustment for path
#

exports.basenameScore = (string, query, score) ->
  return 0 if score == 0
  end = string.length - 1
  end-- while string[end] is PathSeparator # Skip trailing slashes

  basePos = string.lastIndexOf(PathSeparator, end)

  # No PathSeparator.. no special base to score
  return score if (basePos == -1)

  # Get baseScore bonus
  baseScore = Math.max(score, exports.score(string.substring(basePos + 1, end + 1), query))

  # We'll merge some of that bonus with full path score.
  # Importance of bonus fade with directory depth until it reach 50/50
  alpha = 0.5 + 2.5 / ( 5.0 + countDir(string, end + 1) )
  score = alpha * baseScore + (1 - alpha) * score

  return score

#
# Count number of folder in a path.
#

countDir = (path, end) ->
  return 0 if end < 1

  count = 0
  i = -1
  while ++i < end

    p = path[i]
    if (p == PathSeparator)
      ++count
      continue while ++i < end and path[i] == PathSeparator

    else if p == "." and ++i < end and path[i] == "." and ++i < end and path[i] == "/"
      --count

  # dot behavior:
  # a) go back one folder in "../"
  # b) suppress next char: "./" is current folder
  # c) normal char ".git/"

  return count