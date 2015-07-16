#
# Score similarity between two string
#
#  isMatch: Fast detection if all character of needle is in haystack
#  score: Find string similarity using a Smith Waterman algorithm
#         Modified to account for programing scenarios (CamelCase folder/file.ext object.property)
#
# Copyright (C) 2015 Jean Christophe Roy and contributors
# MIT License: http://opensource.org/licenses/MIT


wm = 100 # base score of making a match
wc = 200 # bonus for proper case

wa = 400 # bonus of making an acronym match
ws = 200 # bonus of making a separator match

we = -10 # penalty to skip a letter inside a match (vs free to skip around the match)

wst = 100 # bonus for match near start of string
wex = 1000 # bonus per character of an exact match. If exact coincide with prefix, bonus will be 2*wex, then it'll fade to 1*wex as string happens later.

#Note: extra zeros are there to allow rounding the fading bonus function to an integer value.

#
# Fading function
#
# f(x) = tau / ( tau + x) will be used for bonus that fade with position and to to penalize larger haystack.
# tau is the value of x, for which f(x) = 0.5*f(0) = 0.5

tau = 15

#
# Separators
#

separators = ' .-_/\\'
PathSeparator = require('path').sep

#Save above separator in a dictionary for quick lookup
sep_map = do ->
  map = {}
  map[sep] = sep for sep in separators
  return map


# Optional chars
# Some characters of query char MUST be in subject,
# Others COULD be there or not, better Score if they are, but don't block isMatch.

opt_char_re = /[ _\-]/g

exports.coreChars = coreChars = (query) ->
  return query.replace(opt_char_re, '')

#
# Search window
# string_match compute the score using first occurrence of character.
# we'll consider all occurrences, but limit this search of the best occurrence to
# a window at the start of the string. This mostly concern deeply nested path
# and they receive a special treatment for baseName.
#
# Exact match will still continue to search full string.
#

fuzzyMaxlen = 64

#
# isMatch:
# Are all characters of query in subject, in proper order
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

#----------------------------------------------------------------------

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
  # Mix start favoring base Path then favor full path as directory depth increase
  # Note that base Path test are more nested than original, so we have to compensate one level of nesting.

  alpha = 0.5 * 2 * tau / ( 2 * tau + countDir(string, end + 1) )
  return  alpha * basePathScore + (1 - alpha) * fullPathScore

#
# Count number of folder in a path.
# (skip consecutive slashes)

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

  return count

#----------------------------------------------------------------------

#
# Main scoring algorithm
#

exports.score = score = (subject, query) ->
  m = query.length + 1
  n = subject.length + 1

  #haystack size penalty
  sz = 4 * tau / (4 * tau + n)

  #max string size
  n = fuzzyMaxlen + 1 if n > fuzzyMaxlen

  #precompute lowercase
  subject_lw = subject.toLowerCase()
  query_lw = query.toLowerCase()


  #----------------------------
  # Exact Match
  # => bypass

  if ( p = subject_lw.indexOf(query_lw)) > -1

    #bonus per consecutive char grow with number of consecutive
    #so this need to be squared to stay on top.
    base = wex * m * m

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
      exact += 2 * base

    else
      #test for abbreviation
      abbr = abbrPrefix(query, query_lw, subject, subject_lw)
      abbrBonus = abbr.bonus
      exact += 1.5 * wex * abbrBonus * abbrBonus * (1.0 + tau / (tau + abbr.pos))

    return exact * sz

  #----------------------------
  # Abbreviations sequence

  abbr = abbrPrefix(query, query_lw, subject, subject_lw)
  abbrBonus = abbr.bonus
  exact = 5 * wex * abbrBonus * abbrBonus * (1.0 + tau / (tau + abbr.pos))

  #Whole query is abbreviation ? then => bypass
  if( abbr.count == query.length)
    return exact * sz

  #----------------------------
  # Individual chars
  # (Smith Waterman algorithm)

  #Init
  vRow = new Array(n)
  seqRow = new Array(n)
  vmax = 0

  #Fill with 0
  j = -1
  while ++j < n
    vRow[j] = 0
    seqRow[j] = 0

  i = 0 #1..m-1
  while ++i < m     #foreach char of query

    v_diag = vRow[0]
    seq_diag = seqRow[0]

    j = 0 #1..n-1
    while ++j < n   #foreach char of subject

      #Compute a tentative match
      if ( query_lw[i - 1] == subject_lw[j - 1] )

        #forward search for a sequence of consecutive char (will apply some bonus for exact casing or complete match)
        csc = if seq_diag == 0 then countConsecutive(query, query_lw, subject, subject_lw, i - 1, j - 1) else  seq_diag
        seq_diag = seqRow[j]
        seqRow[j] = csc

        #determine bonus for matching A[i-1] with B[j-1]
        align = v_diag + csc * scoreMatchingChar(query, subject, i - 1, j - 1, abbrBonus)

      else
        seq_diag = seqRow[j]
        seqRow[j] = 0
        align = 0

      #Compare the score of making a match, a gap in Query (A), or a gap in Subject (B)
      v_diag = vRow[j]
      gapA = vRow[j] + we
      gapB = vRow[j - 1] + we
      gap = if(gapA > gapB) then gapA else gapB
      v = vRow[j] = if(align > gap) then align else gap

      #Record the best score so far
      if v > vmax
        vmax = v


  return (vmax + exact) * sz

#
# Compute the bonuses for two chars that are confirmed to matches in a case-insensitive way
#

scoreMatchingChar = (query, subject, i, j, abbrBonus) ->
  qi = query[i]
  sj = subject[j]

  #Proper casing bonus
  bonus = if qi == sj then wc else 0

  #start of string bonus
  bonus += Math.floor(wst * tau / (tau + j))

  #match IS a separator
  return ws + bonus if qi of sep_map

  acn = wa * (1+abbrBonus)

  #match is FIRST char ( place a virtual token separator before first char of string)
  return acn + bonus if  j == 0

  #get previous char
  prev_s = subject[j - 1]

  #match FOLLOW a separator
  return acn + bonus if ( prev_s of sep_map)

  #match is Capital in camelCase (preceded by lowercase)
  return acn + bonus if (sj == sj.toUpperCase() and prev_s == prev_s.toLowerCase())

  #normal Match, add proper case bonus
  return wm + bonus

#
# Count consecutive
#

countConsecutive = (query, query_lw, subject, subject_lw, i, j) ->
  m = query.length
  n = subject.length

  mi = m - i
  nj = n - j

  k = if mi < nj then mi else nj
  sameCase = 0

  sz = -1
  while (++sz < k and query_lw[i] == subject_lw[j])
    sameCase++ if (query[i] == subject[j])
    i++
    j++

  # exact match bonus (like score IndexOf)
  if sameCase == m
    return 8 * (m)
  if sz == m
    return 2 * (sz + sameCase )
  else
    return sz + sameCase


#
# Count the number of abbreviation prefix
# Normal char use help of a matching context to determine which one should we take.
# That context is basically the length of the consecutive run they are part of.
#
# This mirror the idea of consecutive run length,
# but compute consecutive of the abbreviated match
# ThisIsTest -> tst
#
# This handle "CamelCase" , "Title Case" "snake_case"
#

class AbbrInfo
  constructor: (@bonus, @pos, @count) ->

abbrInfo0 = new AbbrInfo(0,0.1,0)

abbrPrefix = (query, query_lw, subject, subject_lw) ->

  m = query.length
  n = subject.length
  return abbrInfo0 unless m and n

  #Abbreviation is a fuzzy match
  n = fuzzyMaxlen if n > fuzzyMaxlen

  count = 0
  pos = 0
  sameCase = 0

  i = -1
  j = -1
  k = n - 1

  while ++i < m

    qi_lw = query_lw[i]

    while ++j < n

      sj_lw = subject_lw[j]

      #we have a match
      if(qi_lw == sj_lw)

        sj = subject[j]

        # Is it CamelCase ?
        # 1) sj is Uppercase ( different from sj.toLowerCase() ) AND
        # 2) j is first char or lowercase
        #
        # Is it snake_case ?
        # 1) j is first char or subject[j-1] is separator

        prev_s = if j==0 then '' else subject[j-1]

        if  j==0  or ( prev_s of sep_map ) or  (sj != sj_lw and prev_s == subject_lw[j-1] )

          #record position and increase count
          pos += j
          count++

          #Is it sameCase ?
          sameCase++ if ( query[i] == sj )

          break

    #all of subject is consumed.
    if j==k then break

  #all of query is consumed.
  #a single char is not an acronym (also prevent division by 0)
  if(count < 2)
    return abbrInfo0

  return new AbbrInfo(count + sameCase, pos/count, count)




#----------------------------------------------------------------------

#
# Align sequence (used for match)
# Return position of subject that match query.
#

exports.align = (subject, query, offset = 0) ->
  m = query.length + 1
  n = subject.length + 1

  #max string size
  n = fuzzyMaxlen + 1 if n > fuzzyMaxlen

  subject_lw = subject.toLowerCase()
  query_lw = query.toLowerCase()

  #this is like the consecutive bonus, but for scattered camelCase initials
  nbc = abbrPrefix(query, query_lw, subject, subject_lw).bonus

  #Init
  vRow = new Array(n)
  seqRow = new Array(n)
  vmax = 0
  imax = -1
  jmax = -1

  # Directions constants
  STOP = 0
  UP = 1
  LEFT = 2
  DIAGONAL = 3

  #Traceback matrix
  trace = new Array(m * n)
  pos = n - 1

  #Fill with 0
  j = -1
  while ++j < n
    vRow[j] = 0
    seqRow[j] = 0
    trace[j] = STOP

  i = 0 #1..m-1
  while ++i < m #foreach char of query

    gapB = 0
    v_diag = vRow[0]
    seq_diag = seqRow[0]
    pos++
    trace[pos] = STOP

    j = 0 #1..n-1
    while ++j < n #foreach char of subject

      # Score the options
      # When comparing string A,B character per character
      # we have 3 possible choices.
      #
      # 1) Remove character A[i] from the total match
      # 2) Remove characer B[j] fromt the total match
      # 3) Attempt to match A[i] with B[j]
      #
      # For the point 3, if char are different in a case insensitive way, score is 0
      # if they are similar, take previous diagonal score (v_diag) and add similarity score.
      # we use similarity(A,B) as an entry point to give various bonuses.

      #Compute a tentative match
      if ( query_lw[i - 1] == subject_lw[j - 1] )

        if seq_diag == 0

          #forward search for a sequence of consecutive char (will apply some bonus for exact casing or exact match)
          csc = countConsecutive(query, query_lw, subject, subject_lw, i - 1, j - 1)

        else
          # Verify that previous char is a Match before applying sequence bonus.
          # (this is not done for score because we don't keep trace)
          csc = if trace[pos - n] == DIAGONAL then seq_diag else 1

        seq_diag = seqRow[j]
        seqRow[j] = csc

        align = v_diag + csc * scoreMatchingChar(query, subject, i - 1, j - 1, nbc)

      else
        seq_diag = seqRow[j]
        seqRow[j] = 0
        align = 0

      #Compare the score of making a match, a gap in Query (A), or a gap in Subject (B)
      v_diag = vRow[j]
      gapA = vRow[j] + we
      gapB = vRow[j - 1] + we
      gap = if(gapA > gapB) then gapA else gapB
      v = vRow[j] = if(align > gap) then align else gap

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
        matches.push j + offset
        j--
        i--
        pos -= n + 1
      else
        backtrack = false

  matches.reverse()
  return matches
