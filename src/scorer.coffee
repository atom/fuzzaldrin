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

wa = 40 # bonus of making an acronym match
ws = 20 # bonus of making a separator match

wo = -10 # penalty to open a gap
we = -1 # penalty to continue an open gap (inside a match)

wst = 15 # bonus for match near start of string
wex = 60 # bonus per character of an exact match. If exact coincide with prefix, bonus will be 2*wex, then it'll fade to 1*wex as string happens later.

#
# Fading function
#
# f(x) = tau / ( tau + x) will be used for bonus that fade with position
# it'll also be used to penalize larger haystack.
#
# f(0) = 1, f(half_score) = 0.5
# tau / ( tau + half_score) = 0.5
# tau / ( tau + tau) = 0.5 => tau = half_score

tau = 10


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

opt_char_re = /[ _\-]/g

#
# Main scoring algorithm
#

exports.score = score = (subject, query) ->
  m = query.length + 1
  n = subject.length + 1

  subject_lw = subject.toLowerCase()
  query_lw = query.toLowerCase()

  #haystack size penalty
  sz = 4*tau / (4*tau + n)

  #----------------------------
  # Exact Match
  # => bypass

  if ( p = subject_lw.indexOf(query_lw)) > -1

    base = wex * m

    #base bonus + position decay
    exact = base * (1.0 + tau / (tau + p))

    #sustring happens right after a separator (prefix)
    if (p == 0 or subject[p - 1] of sep_map)
      exact += 4 * base

    # last position, the +1s cancel out
    # for both the "length=<last index>+1" and the buffer=length+1
    lpos = n - m

    #sustring happens right before a separator (suffix)
    if (p == lpos or subject[p + 1] of sep_map)
      exact += base

    if(subject.indexOf(query) > -1)
      #substring is ExactCase
      exact += 2*base

    else
      #test for camelCase
      camel = camelPrefix(subject, subject_lw, query, query_lw)
      exact += 1.5 * wex * camel[0] * (1.0 + tau / (tau + camel[1]))

    return exact * sz

  #----------------------------
  # Abbreviations sequence

  # for example, if we type "surl" to search StatusUrl
  # this will recognize and boost "su" as CamelCase sequence
  # then "surl" will be passed to next scoring step.

  #test for camelCase
  camel = camelPrefix(subject, subject_lw, query, query_lw)
  exact = 3 * wex * camel[0] * (1.0 + tau / (tau + camel[1]))

  #Whole query is camelCase abbreviation ? then => bypass
  if(camel[0] == query.length)
    return exact

  #----------------------------
  # Individual chars
  # (Smith Waterman Gotoh algorithm)

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

      # score the options
      gapA = gapArow[j] = Math.max(gapArow[j] + we, vrow[j] + wo)
      gapB = Math.max(gapB + we, vrow[j - 1] + wo)
      align = if ( query_lw[i - 1] == subject_lw[j - 1] ) then vd + scoreMatchingChar(query, subject, i - 1, j - 1) else 0
      vd = vrow[j]

      #Get the best option (align set the lower-bound to 0)
      v = vrow[j] = Math.max(align, gapA, gapB)

      #Record best score
      if v > vmax
        vmax = v


  return (vmax + exact) * sz

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

  #match is FIRST char ( place a virtual token separator before first char of string)
  return wa + bonus if ( j == 0 or i == 0)

  #get previous char
  prev_s = subject[j - 1]
  prev_q = query[i - 1]

  #match FOLLOW a separator
  return wa + bonus if ( prev_s of sep_map) or ( prev_q of sep_map )

  #match is Capital in camelCase (preceded by lowercase)
  return wa + bonus if (sj == sj.toUpperCase() and prev_s == prev_s.toLowerCase())

  #normal Match, add proper case bonus
  return wm + bonus


#
# Count the number of camelCase prefix
# Note that case insensitive character such as space will count as lowercase.
# So this handle both "CamelCase" and "Title Case"

camelPrefix = (subject, subject_lw, query, query_lw) ->

  m = query_lw.length
  n = subject_lw.length

  count = 0
  pos = 0

  i = -1
  j = -1
  k = n - 1

  while ++i < m

    qi_lw = query_lw[i]

    while ++j < n

      sj = subject[j]
      sj_lw = subject_lw[j]

      #Lowecase, continue
      if(sj == sj_lw) then continue

      #Subject Uppercase, is it a match ?
      else if( qi_lw == sj_lw )

        #record position
        pos = j if count == 0

        #Is Query Uppercase too ?
        qi = query[i]
        count += if( qi == qi.toUpperCase() ) then 2 else 1

        break

      #End of subject
      if j == k then return [count, pos]

      else
        # Skipped a CamelCase candidate...
        # Lower quality of the match by increasing first match pos
        pos+=2

  #end of query
  return [count, pos]

#
# filer query until we only get required char
#

exports.coreChars = coreChars = (query) ->
  return query.replace(opt_char_re, '')


#
# yes/no: is all required characters of query in subject, in proper order
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

exports.basenameScore = (string, query, fullPathScore) ->
  return 0 if fullPathScore == 0

  # Skip trailing slashes
  end = string.length - 1
  end-- while string[end] is PathSeparator

  # Get position of basePath of string. If no PathSeparator, no base path exist.
  basePos = string.lastIndexOf(PathSeparator, end)
  return fullPathScore if (basePos == -1)

  # Get basePath score
  basePathScore = score(string.substring(basePos + 1, end + 1), query)

  # We'll merge some of that base path score with full path score.
  # Mix start at 50/50 then favor of full path as directory depth increase
  alpha = 2.5 / ( 5.0 + countDir(string, end + 1) )
  fullPathScore = alpha * basePathScore + (1 - alpha) * fullPathScore

  return fullPathScore

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
      while ++i < end and path[i] == PathSeparator
        continue

    else if p == "." and ++i < end and path[i] == "." and ++i < end and path[i] == "/"
      --count

  # dot behavior:
  # a) go back one folder in "../"
  # b) suppress next char: "./" is current folder
  # c) normal char ".git/"

  return count


#
# Align sequence
# Return position of subject that match query.
#


# Directions constants
STOP = 0
UP = 1
LEFT = 2
DIAGONAL = 3

exports.align = (subject, query, offset = 0) ->

  m = query.length + 1
  n = subject.length + 1

  subject_lw = subject.toLowerCase()
  query_lw = query.toLowerCase()

  #Init
  vrow = new Array(n)
  gapArow = new Array(n)
  gapA = 0
  gapB = 0
  vmax = 0
  imax = -1
  jmax = -1

  trace = new Array(m * n)
  pos = n - 1


  #Fill with 0
  j = -1
  while ++j < n
    gapArow[j] = 0
    vrow[j] = 0
    trace[j] = STOP

  i = 0 #1..m-1
  while ++i < m #foreach char of query

    gapB = 0
    vd = vrow[0]
    pos++
    trace[pos] = STOP

    j = 0 #1..n-1
    while ++j < n #foreach char of subject

      # score the options
      gapA = gapArow[j] = Math.max(gapArow[j] + we, vrow[j] + wo)
      gapB = Math.max(gapB + we, vrow[j - 1] + wo)
      align = if ( query_lw[i - 1] == subject_lw[j - 1] ) then vd + scoreMatchingChar(query, subject, i - 1, j - 1) else 0
      vd = vrow[j]

      #Get the best option (align set the lower-bound to 0)
      v = vrow[j] = Math.max(align, gapA, gapB)

      # what triggered the best score ?
      #In case of equality, taking gapB get us closer to the start of the string.

      pos++ #pos = i * n + j
      switch v
        when 0
          trace[pos] = STOP
        when gapB
          trace[pos] = LEFT
        when gapA
          trace[pos] = UP
        when align
          trace[pos] = DIAGONAL
          #Record best score
          if v > vmax
            vmax = v
            imax = i
            jmax = j

        else
          trace[pos] = STOP
          break

  # -------------------
  # Go back in the trace matrix from imax, jmax
  # and collect diagonals

  i = imax
  j = jmax
  pos = i * n + j
  backtrack = true
  matches = []
  offset--

  while backtrack
    switch trace[pos]
      when UP
        i--
        pos -= n
      when LEFT
        j--
        pos--
      when DIAGONAL
        matches.push j+offset
        j--
        i--
        pos -= n + 1
      else
        backtrack = false

  matches.reverse()
  return matches
