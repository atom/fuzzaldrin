#
# Score similarity between two string
#
#  isMatch: Fast detection if all character of needle is in haystack
#  score: Find string similarity using a Smith Waterman algorithm
#         Modified to account for programing scenarios (CamelCase folder/file.ext object.property)
#
# Copyright (C) 2015 Jean Christophe Roy and contributors
# MIT License: http://opensource.org/licenses/MIT
#
# Previous version of scorer used string_score from Joshaven Potter
# https://github.com/joshaven/string_score/


wm = 100 # base score of making a match
wc = 200 # bonus for proper case

wa = 300 # bonus of making an acronym match
ws = 200 # bonus of making a separator match

we = -10 # penalty to skip a letter inside a match (vs free to skip around the match)

wst = 100 # bonus for match near start of string
wex = 1000 # bonus per character of an exact match. If exact coincide with prefix, bonus will be 2*wex, then it'll fade to 1*wex as string happens later.

#Note: extra zeros are there to allow rounding the fading bonus function to an integer value.

#
# Fading function
#
# f(x) = tau / ( tau + x) will be used for bonus that fade with position
# it'll also be used to penalize larger haystack.
#
# f(0) = 1, f(half_score) = 0.5
# tau / ( tau + half_score) = 0.5
# tau / ( tau + tau) = 0.5 => tau = half_score

tau = 15


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

    #bonus per consecutive char grow with number of consecutive
    #so this need to be squared to stay on top.
    base = wex * m *m

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
      camelCount =  camel[2]
      if camelCount > 1 #don't count a single capital as camel
        camelBonus =  camel[0]
        exact += 1.5 * wex * camelBonus * camelBonus * (1.0 + tau / (tau + camel[1]))

    return exact * sz

  #----------------------------
  # Abbreviations sequence

  # for example, if we type "surl" to search StatusUrl
  # this will recognize and boost "su" as CamelCase sequence
  # then "surl" will be passed to next scoring step.

  #test for camelCase
  camel = camelPrefix(subject, subject_lw, query, query_lw)
  camelCount =  camel[2]
  exact = 0
  if camelCount > 1
    camelBonus =  camel[0]
    exact += 5 * wex * camelBonus * camelBonus * (1.0 + tau / (tau + camel[1]))

    #Whole query is camelCase abbreviation ? then => bypass
    if( camelCount == query.length)
      return exact * sz

  #----------------------------
  # Individual chars
  # (Smith Waterman Gotoh algorithm)

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

        #forward search for a sequence of consecutive char (will apply some bonus for exact casing or exact match)
        csc = if seq_diag == 0 then countConsecutive(query, query_lw, subject, subject_lw, i-1 , j-1 ) else  seq_diag
        seq_diag = seqRow[j]
        seqRow[j] = csc

        #determine bonus for matching A[i-1] with B[j-1]
        align =  v_diag + csc*scoreMatchingChar(query, subject, i - 1, j - 1, camelBonus)

      else
        seq_diag = seqRow[j]
        seqRow[j] = 0
        align = 0

      #Compare the score of making a match, a gap in Query (A), or a gap in Subject (B)
      v_diag = vRow[j]
      v = vRow[j] = Math.max(align, vRow[j] + we, vRow[j - 1] + we)

      #Record the best score so far
      if v > vmax
        vmax = v


  return (vmax + exact) * sz

#
# Compute the bonuses for two chars that are confirmed to matches in a case-insensitive way
#

scoreMatchingChar = (query, subject, i, j, camelBonus) ->

  qi = query[i]
  sj = subject[j]

  #Proper casing bonus
  bonus = if qi == sj then wc else 0

  #start of string bonus
  bonus += Math.floor(wst * tau / (tau  + j))

  #match IS a separator
  return ws + bonus if qi of sep_map

  #match is FIRST char ( place a virtual token separator before first char of string)
  return wa + bonus if  j == 0

  #get previous char
  prev_s = subject[j - 1]

  #match FOLLOW a separator
  return wa + bonus if ( prev_s of sep_map)

  #match is Capital in camelCase (preceded by lowercase)
  return (1 + camelBonus) * wa + bonus if (sj == sj.toUpperCase() and prev_s == prev_s.toLowerCase())

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
  sameCase = 0

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
        #pos = j if count == 0
        pos += j

        #Is Query Uppercase too ?
        qi = query[i]
        count++
        sameCase++ if( qi == qi.toUpperCase() )

        break

      #End of subject
      if j == k then return [count+sameCase, pos / (count + 1), count]

      else
        # Skipped a CamelCase candidate...
        # Lower quality of the match by increasing first match pos
        pos+=3

  #end of query
  return [count+sameCase, pos / (count + 1), count]

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
# Count consecutive
#

countConsecutive = (query, query_lw, subject, subject_lw, i , j ) ->

  m = query.length
  dm = query.length - i
  dn = subject.length - j
  k = if dm<dn then dm else dn

  sameCase = 0

  f=-1
  while (++f<k and query_lw[i+f] == subject_lw[j+f])
    if (query[i+f] == subject[j+f]) then sameCase++

  # exact match bonus (like score IndexOf)
  if sameCase == m
    return 5*m
  if f==m
    return 2*(f+sameCase)
  else
    return f+sameCase



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

  alpha = 0.5 * 2*tau / ( 2*tau + countDir(string, end + 1) )
  return  alpha * basePathScore + (1 - alpha) * fullPathScore

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

  #this is like the consecutive bonus, but for scattered camelCase initials
  nbc = camelPrefix(subject, subject_lw, query, query_lw)[0]

  #Init
  vRow = new Array(n)
  seqRow = new Array(n)
  vmax = 0
  imax = -1
  jmax = -1

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
      #
      # We also keep track of match context. If we are inside a run of consecutive matches, all bonuses are increased
      # And so are all penalty. (Encourage matching, discourage non matching)


      #Compute a tentative match
      if ( query_lw[i - 1] == subject_lw[j - 1] )

        if seq_diag == 0

          #forward search for a sequence of consecutive char (will apply some bonus for exact casing or exact match)
          csc =  countConsecutive(query, query_lw, subject, subject_lw, i-1 , j-1 )

        else
          # Verify that previous char is a Match before applying sequence bonus.
          # (this is not done for score because we don't keep trace)
          csc = if trace[pos-n] == DIAGONAL then seq_diag else 1

        seq_diag = seqRow[j]
        seqRow[j] = csc

        align =  v_diag + csc*scoreMatchingChar(query, subject, i - 1, j - 1, nbc)

      else
        seq_diag = seqRow[j]
        seqRow[j] = 0
        align = 0

      #Compare the score of making a match, a gap in Query (A), or a gap in Subject (B)
      v_diag = vRow[j]
      gapA = vRow[j] + we
      gapB =  vRow[j - 1] + we
      v = vRow[j] = Math.max(align, gapA, gapB)

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
        matches.push j+offset
        j--
        i--
        pos -= n + 1
      else
        backtrack = false

  matches.reverse()
  return matches
