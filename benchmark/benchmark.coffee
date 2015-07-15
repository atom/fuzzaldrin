fs = require 'fs'
path = require 'path'

{filter, match} = require '../lib/fuzzaldrin'

lines = fs.readFileSync(path.join(__dirname, 'data.txt'), 'utf8').trim().split('\n')

console.log("======")

startTime = Date.now()
results = filter(lines, 'index')
console.log("Filtering #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results.length} results (~10% of results are positive, mix exact & fuzzy)")

startTime = Date.now()
results2 = filter(lines, 'index', {legacy:true})
console.log("Filtering #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results2.length} results (~10% of results are positive, Legacy method)")

console.log("======")

startTime = Date.now()
results3 = filter(lines, 'node')
console.log("Filtering #{lines.length} entries for 'node' took #{Date.now() - startTime}ms for #{results3.length} results (~98% of results are positive, mostly Exact match)")

startTime = Date.now()
results4 = filter(lines, 'node')
console.log("Filtering #{lines.length} entries for 'node' took #{Date.now() - startTime}ms for #{results4.length} results (~98% of results are positive, Legacy method)")

console.log("======")

startTime = Date.now()
results5 = filter(lines, 'nde')
console.log("Filtering #{lines.length} entries for 'nde' took #{Date.now() - startTime}ms for #{results5.length} results (~98% of results are positive, Fuzzy match, [Worst case scenario])")

startTime = Date.now()
results6 = filter(lines, 'indx')
console.log("Filtering #{lines.length} entries for 'indx' took #{Date.now() - startTime}ms for #{results6.length} results (~10% of results are positive, Fuzzy match)")

startTime = Date.now()
results7 = filter(lines, 'nm')
console.log("Filtering #{lines.length} entries for 'nm' took #{Date.now() - startTime}ms for #{results7.length} results (~98% of results are positive, Acronym)")

console.log("======")

startTime = Date.now()
match(line, 'index') for line in lines
console.log("Matching #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results.length} results")

if results.length isnt 6168
  console.error("Results count changed! #{results.length} instead of 6168")
  process.exit(1)
